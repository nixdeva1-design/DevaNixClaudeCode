-- =============================================================
-- MODULE 08: Geo tabellen (zones, ringen, toewijzingen, locatie log, overtredingen)
-- Vervanging: vervang dit bestand voor ander zone/geofencing model
-- Afhankelijkheden: 02_tables_core.sql, 03_tables_devices.sql
-- Concept: concentrische radius ringen per zone
--   ring 1 = binnenste (bureau 0-5m)
--   ring 2 = afdeling  (5-30m)
--   ring 3 = verdieping (30-100m)
--   ring 4 = gebouw    (100-300m)
-- =============================================================

-- Zones: benoemde locaties per klant of kantoor
CREATE TABLE IF NOT EXISTS zones (
    ulid          TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                          CHECK (is_valid_ulid(ulid)),
    naam          TEXT    NOT NULL,
    eigenaar_type TEXT    NOT NULL CHECK (eigenaar_type IN ('kantoor', 'klant')),
    eigenaar_ulid TEXT    NOT NULL CHECK (is_valid_ulid(eigenaar_ulid)),
    center_lat    NUMERIC(10, 7) NOT NULL,
    center_lon    NUMERIC(10, 7) NOT NULL,
    beschrijving  TEXT,
    actief        BOOLEAN NOT NULL DEFAULT TRUE,
    aangemaakt_op BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT
);

-- Zone ringen: concentrische cirkels rondom zone centrum
CREATE TABLE IF NOT EXISTS zone_ringen (
    ulid          TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                          CHECK (is_valid_ulid(ulid)),
    zone_ulid     TEXT    NOT NULL REFERENCES zones(ulid),
    ring_naam     TEXT    NOT NULL,
    ring_volgorde INTEGER NOT NULL CHECK (ring_volgorde > 0),
    radius_min_m  NUMERIC NOT NULL DEFAULT 0 CHECK (radius_min_m >= 0),
    radius_max_m  NUMERIC NOT NULL CHECK (radius_max_m > 0),
    alert_niveau  TEXT    NOT NULL CHECK (alert_niveau IN ('info','waarschuwing','kritiek')),
    actief        BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_ring_radius  CHECK (radius_max_m > radius_min_m),
    UNIQUE (zone_ulid, ring_volgorde)
);

-- Toewijzing: welk device is in welke zone, tot welke ring toegestaan
-- Fix t.o.v. origineel: partial unique index i.p.v. UNIQUE(device_ulid, actief)
CREATE TABLE IF NOT EXISTS device_zone_toewijzing (
    ulid                TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                                CHECK (is_valid_ulid(ulid)),
    device_ulid         TEXT    NOT NULL REFERENCES devices(ulid),
    zone_ulid           TEXT    NOT NULL REFERENCES zones(ulid),
    max_toegestane_ring INTEGER NOT NULL DEFAULT 2,
    geldig_van          BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
    geldig_tot          BIGINT,
    toegewezen_door     TEXT    NOT NULL REFERENCES personen(ulid),
    actief              BOOLEAN NOT NULL DEFAULT TRUE
);

-- Slechts 1 actieve toewijzing per device (partial unique index)
CREATE UNIQUE INDEX IF NOT EXISTS uq_device_actieve_zone
    ON device_zone_toewijzing (device_ulid)
    WHERE actief = TRUE;

-- GPS polling log: elke gemeten positie vastgelegd
CREATE TABLE IF NOT EXISTS device_locatie_log (
    ulid                   TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                                   CHECK (is_valid_ulid(ulid)),
    device_ulid            TEXT    NOT NULL REFERENCES devices(ulid),
    gps_lat                NUMERIC(10, 7) NOT NULL,
    gps_lon                NUMERIC(10, 7) NOT NULL,
    nauwkeurigheid_m       NUMERIC,
    tijdstip               BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
    afstand_tot_center_m   NUMERIC,
    ring_ulid              TEXT    REFERENCES zone_ringen(ulid),
    binnen_toegestane_ring BOOLEAN
);

-- Overtredingen: device buiten toegestane ring of verkeerde zone
CREATE TABLE IF NOT EXISTS zone_overtredingen (
    ulid             TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                             CHECK (is_valid_ulid(ulid)),
    device_ulid      TEXT    NOT NULL REFERENCES devices(ulid),
    toewijzing_ulid  TEXT    REFERENCES device_zone_toewijzing(ulid),
    locatie_log_ulid TEXT    REFERENCES device_locatie_log(ulid),
    overtreding_type TEXT    NOT NULL CHECK (overtreding_type IN (
                                 'buiten_zone', 'verkeerde_zone',
                                 'onbekende_locatie', 'verwisseld_device'
                             )),
    afstand_m        NUMERIC,
    alert_niveau     TEXT    NOT NULL CHECK (alert_niveau IN ('info','waarschuwing','kritiek')),
    tijdstip         BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
    afgehandeld      BOOLEAN NOT NULL DEFAULT FALSE,
    afgehandeld_door TEXT    REFERENCES personen(ulid),
    afgehandeld_op   BIGINT,
    notitie          TEXT
);
