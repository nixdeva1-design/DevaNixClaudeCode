-- =============================================================
-- MODULE 09: Operationele functies
-- Vervanging: vervang dit bestand voor andere remote beheer implementatie
-- Afhankelijkheden: alle tabel modules (03, 05, 06, 07, 08)
-- Functies:
--   ontkoppel_device()       — remote device blokkering bij diefstal
--   verwerk_gps_positie()    — GPS polling verwerking + overtreding detectie
--   wijs_device_zone_toe()   — zone toewijzing aanpassen op afstand
-- =============================================================

-- Remote ontkoppeling bij diefstal of verlies
-- Cascade: device → licenties → installaties → processen gestopt
-- Alleen beheerder (Cuiper/Deva) mag uitvoeren
CREATE OR REPLACE FUNCTION ontkoppel_device(
    p_device_ulid TEXT,
    p_door_ulid   TEXT
)
RETURNS VOID AS $$
DECLARE
    v_now BIGINT := EXTRACT(EPOCH FROM NOW())::BIGINT;
BEGIN
    IF NOT is_beheerder(p_door_ulid) THEN
        RAISE EXCEPTION
            'Onvoldoende rechten: alleen Cuiper of Deva mag ontkoppelen (actor: %)',
            p_door_ulid;
    END IF;

    UPDATE devices SET
        gestolen           = TRUE,
        gestolen_gemeld_op = v_now,
        ontkoppeld_op      = v_now,
        ontkoppeld_door    = p_door_ulid,
        actief             = FALSE
    WHERE ulid = p_device_ulid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Device % niet gevonden', p_device_ulid;
    END IF;

    UPDATE licenties   SET actief = FALSE       WHERE device_ulid = p_device_ulid;
    UPDATE software_installaties SET
        status = 'gestopt', bijgewerkt_op = v_now, bijgewerkt_door = p_door_ulid
    WHERE device_ulid = p_device_ulid AND status = 'actief';
    UPDATE processen   SET status = 'mislukt', end_unix = v_now
    WHERE device_ulid = p_device_ulid AND status = 'actief';

    RAISE NOTICE '[ONTKOPPELD] device=% door=% op=%', p_device_ulid, p_door_ulid, v_now;
END;
$$ LANGUAGE plpgsql;

-- GPS positie verwerken: log + ring bepalen + overtreding detecteren
-- Fix t.o.v. origineel: v_ring NULL check vóór v_ring.ulid toegang
CREATE OR REPLACE FUNCTION verwerk_gps_positie(
    p_device_ulid    TEXT,
    p_lat            NUMERIC,
    p_lon            NUMERIC,
    p_nauwkeurigheid NUMERIC DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_now        BIGINT := EXTRACT(EPOCH FROM NOW())::BIGINT;
    v_toewijzing RECORD;
    v_ring       RECORD;
    v_afstand    NUMERIC := NULL;
    v_log_ulid   TEXT    := ck_gen_ulid();
    v_ring_ulid  TEXT    := NULL;
    v_binnen     BOOLEAN := FALSE;
    v_type       TEXT;
    v_alert      TEXT;
BEGIN
    SELECT dzt.*, z.center_lat, z.center_lon
    INTO v_toewijzing
    FROM device_zone_toewijzing dzt
    JOIN zones z ON z.ulid = dzt.zone_ulid
    WHERE dzt.device_ulid = p_device_ulid
      AND dzt.actief = TRUE
      AND (dzt.geldig_tot IS NULL OR dzt.geldig_tot >= v_now)
    LIMIT 1;

    IF v_toewijzing IS NOT NULL THEN
        v_afstand := gps_afstand_m(p_lat, p_lon,
                         v_toewijzing.center_lat, v_toewijzing.center_lon);
        SELECT * INTO v_ring
        FROM zone_ringen
        WHERE zone_ulid    = v_toewijzing.zone_ulid
          AND radius_min_m <= v_afstand
          AND radius_max_m >  v_afstand
          AND actief = TRUE
        ORDER BY ring_volgorde ASC LIMIT 1;

        IF v_ring IS NOT NULL THEN
            v_ring_ulid := v_ring.ulid;
            v_binnen    := v_ring.ring_volgorde <= v_toewijzing.max_toegestane_ring;
        END IF;
    END IF;

    INSERT INTO device_locatie_log (
        ulid, device_ulid, gps_lat, gps_lon, nauwkeurigheid_m,
        tijdstip, afstand_tot_center_m, ring_ulid, binnen_toegestane_ring
    ) VALUES (
        v_log_ulid, p_device_ulid, p_lat, p_lon, p_nauwkeurigheid,
        v_now, v_afstand, v_ring_ulid, v_binnen
    );

    UPDATE devices SET gps_lat = p_lat, gps_lon = p_lon, gps_bijgewerkt_op = v_now
    WHERE ulid = p_device_ulid;

    IF NOT v_binnen THEN
        IF v_toewijzing IS NULL THEN
            v_type := 'onbekende_locatie'; v_alert := 'waarschuwing';
        ELSIF v_ring IS NULL OR v_ring.ring_volgorde > v_toewijzing.max_toegestane_ring THEN
            v_type := 'buiten_zone';
            v_alert := CASE WHEN v_ring IS NOT NULL THEN v_ring.alert_niveau ELSE 'kritiek' END;
        ELSE
            v_type := 'verkeerde_zone'; v_alert := 'kritiek';
        END IF;

        INSERT INTO zone_overtredingen (
            device_ulid, toewijzing_ulid, locatie_log_ulid,
            overtreding_type, afstand_m, alert_niveau, tijdstip
        ) VALUES (
            p_device_ulid, v_toewijzing.ulid, v_log_ulid,
            v_type, v_afstand, v_alert, v_now
        );
        RAISE NOTICE '[OVERTREDING] device=% type=% afstand=%m alert=%',
            p_device_ulid, v_type, round(COALESCE(v_afstand,0)), v_alert;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Zone toewijzing aanpassen op afstand (alleen beheerder/Cuiper)
CREATE OR REPLACE FUNCTION wijs_device_zone_toe(
    p_device_ulid TEXT,
    p_zone_ulid   TEXT,
    p_max_ring    INTEGER,
    p_door_ulid   TEXT,
    p_geldig_tot  BIGINT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_now  BIGINT := EXTRACT(EPOCH FROM NOW())::BIGINT;
    v_ulid TEXT   := ck_gen_ulid();
BEGIN
    IF NOT is_beheerder(p_door_ulid) THEN
        RAISE EXCEPTION 'Onvoldoende rechten voor zone toewijzing (actor: %)', p_door_ulid;
    END IF;

    UPDATE device_zone_toewijzing
    SET actief = FALSE, geldig_tot = v_now
    WHERE device_ulid = p_device_ulid AND actief = TRUE;

    INSERT INTO device_zone_toewijzing (
        ulid, device_ulid, zone_ulid, max_toegestane_ring,
        geldig_van, geldig_tot, toegewezen_door, actief
    ) VALUES (
        v_ulid, p_device_ulid, p_zone_ulid, p_max_ring,
        v_now, p_geldig_tot, p_door_ulid, TRUE
    );

    RAISE NOTICE '[ZONE TOEWIJZING] device=% zone=% ring<=% door=%',
        p_device_ulid, p_zone_ulid, p_max_ring, p_door_ulid;
    RETURN v_ulid;
END;
$$ LANGUAGE plpgsql;
