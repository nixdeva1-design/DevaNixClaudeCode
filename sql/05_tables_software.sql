-- =============================================================
-- MODULE 05: Software producten + licenties
-- Vervanging: vervang dit bestand voor ander licentie model
-- Afhankelijkheden: 03_tables_devices.sql, 04_tables_mandaten.sql
-- Regels:
--   - 1 licentie per eigenaar (persoon of klant) per product
--   - Licentie vereist actief gedragsmandaat
--   - Personeel: device eigendom kantoor
--   - Klant: device eigendom klant
-- =============================================================

CREATE TABLE IF NOT EXISTS software_producten (
    ulid          TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                          CHECK (is_valid_ulid(ulid)),
    naam          TEXT    NOT NULL,
    versie        TEXT    NOT NULL,
    actief        BOOLEAN NOT NULL DEFAULT TRUE,
    aangemaakt_op BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT
);

-- Licenties voor personen (personeel) en klanten
-- eigenaar_type = 'persoon' → kantoorpersoneel, device eigendom kantoor
-- eigenaar_type = 'klant'   → klant, device eigendom klant
CREATE TABLE IF NOT EXISTS licenties (
    ulid            TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    eigenaar_type   TEXT    NOT NULL CHECK (eigenaar_type IN ('persoon', 'klant')),
    eigenaar_ulid   TEXT    NOT NULL CHECK (is_valid_ulid(eigenaar_ulid)),
    product_ulid    TEXT    NOT NULL REFERENCES software_producten(ulid),
    device_ulid     TEXT    NOT NULL REFERENCES devices(ulid),
    mandaat_ulid    TEXT    NOT NULL REFERENCES mandaten(ulid),
    geldig_van      BIGINT  NOT NULL,
    geldig_tot      BIGINT,
    actief          BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_licentie_eigenaar_product
        UNIQUE (eigenaar_type, eigenaar_ulid, product_ulid)
);

-- Device eigenaar check: klant→klant device, persoon→kantoor device
CREATE OR REPLACE FUNCTION chk_licentie_device_eigenaar()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.eigenaar_type = 'klant' THEN
        IF NOT EXISTS (
            SELECT 1 FROM devices
            WHERE ulid = NEW.device_ulid
              AND eigenaar_type = 'klant'
              AND eigenaar_ulid = NEW.eigenaar_ulid
              AND actief = TRUE
        ) THEN
            RAISE EXCEPTION 'Device % is geen actief device van klant %',
                NEW.device_ulid, NEW.eigenaar_ulid;
        END IF;
    ELSIF NEW.eigenaar_type = 'persoon' THEN
        IF NOT EXISTS (
            SELECT 1 FROM devices
            WHERE ulid = NEW.device_ulid
              AND eigenaar_type = 'kantoor'
              AND actief = TRUE
        ) THEN
            RAISE EXCEPTION 'Device % is geen actief kantoor device voor persoon %',
                NEW.device_ulid, NEW.eigenaar_ulid;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Mandaat op licentie moet type=gedrag en actief zijn
CREATE OR REPLACE FUNCTION chk_licentie_mandaat_type()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM mandaten
        WHERE ulid = NEW.mandaat_ulid
          AND mandaat_type = 'gedrag'
          AND actief = TRUE
    ) THEN
        RAISE EXCEPTION 'Licentie vereist actief gedragsmandaat (mandaat_ulid: %)',
            NEW.mandaat_ulid;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_chk_licentie_device ON licenties;
CREATE TRIGGER trg_chk_licentie_device
    BEFORE INSERT OR UPDATE ON licenties
    FOR EACH ROW EXECUTE FUNCTION chk_licentie_device_eigenaar();

DROP TRIGGER IF EXISTS trg_chk_licentie_mandaat ON licenties;
CREATE TRIGGER trg_chk_licentie_mandaat
    BEFORE INSERT OR UPDATE ON licenties
    FOR EACH ROW EXECUTE FUNCTION chk_licentie_mandaat_type();
