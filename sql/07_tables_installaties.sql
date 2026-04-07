-- =============================================================
-- MODULE 07: Software installaties + audit log
-- Vervanging: vervang dit bestand voor ander installatie tracking model
-- Afhankelijkheden: 03_tables_devices.sql, 05_tables_software.sql, 02_tables_core.sql
-- CRUD types:
--   technisch_config — infrastructuur, poorten, paden, resources
--   gedrag_config    — features, limieten, UI gedrag (per licentie/mandaat)
-- Alle wijzigingen worden automatisch gelogd via trigger
-- =============================================================

CREATE TABLE IF NOT EXISTS software_installaties (
    ulid             TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                             CHECK (is_valid_ulid(ulid)),
    device_ulid      TEXT    NOT NULL REFERENCES devices(ulid),
    product_ulid     TEXT    NOT NULL REFERENCES software_producten(ulid),
    licentie_ulid    TEXT    NOT NULL REFERENCES licenties(ulid),
    versie           TEXT    NOT NULL,
    technisch_config JSONB,
    gedrag_config    JSONB,
    status           TEXT    NOT NULL DEFAULT 'actief'
                             CHECK (status IN ('actief', 'gestopt', 'verwijderd')),
    geinstalleerd_op BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
    bijgewerkt_op    BIGINT,
    bijgewerkt_door  TEXT    NOT NULL REFERENCES personen(ulid),

    UNIQUE (device_ulid, product_ulid)
);

-- Audit log: vastlegging van elke CRUD actie op installaties
CREATE TABLE IF NOT EXISTS installatie_log (
    ulid             TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                             CHECK (is_valid_ulid(ulid)),
    installatie_ulid TEXT    NOT NULL,  -- geen FK: ook verwijderde installaties loggen
    actie            TEXT    NOT NULL CHECK (actie IN (
                                 'create', 'update_technisch', 'update_gedrag', 'delete'
                             )),
    door_persoon_ulid TEXT   NOT NULL REFERENCES personen(ulid),
    oude_waarde      JSONB,
    nieuwe_waarde    JSONB,
    tijdstip         BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT
);

-- Automatische audit log trigger
CREATE OR REPLACE FUNCTION log_installatie_wijziging()
RETURNS TRIGGER AS $$
DECLARE
    v_actie TEXT;
    v_actor TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_actie := 'create';
        v_actor := NEW.bijgewerkt_door;
        INSERT INTO installatie_log
            (installatie_ulid, actie, door_persoon_ulid, nieuwe_waarde)
        VALUES (NEW.ulid, v_actie, v_actor, to_jsonb(NEW));

    ELSIF TG_OP = 'UPDATE' THEN
        v_actor := NEW.bijgewerkt_door;
        IF OLD.technisch_config IS DISTINCT FROM NEW.technisch_config THEN
            v_actie := 'update_technisch';
        ELSE
            v_actie := 'update_gedrag';
        END IF;
        INSERT INTO installatie_log
            (installatie_ulid, actie, door_persoon_ulid, oude_waarde, nieuwe_waarde)
        VALUES (NEW.ulid, v_actie, v_actor, to_jsonb(OLD), to_jsonb(NEW));

    ELSIF TG_OP = 'DELETE' THEN
        v_actor := OLD.bijgewerkt_door;
        INSERT INTO installatie_log
            (installatie_ulid, actie, door_persoon_ulid, oude_waarde)
        VALUES (OLD.ulid, 'delete', v_actor, to_jsonb(OLD));
        RETURN OLD;  -- DELETE trigger geeft OLD terug
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_log_installatie ON software_installaties;
CREATE TRIGGER trg_log_installatie
    AFTER INSERT OR UPDATE OR DELETE ON software_installaties
    FOR EACH ROW EXECUTE FUNCTION log_installatie_wijziging();
