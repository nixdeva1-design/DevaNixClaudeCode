-- =============================================================
-- MODULE 04: Mandaten tabel + gedrag trigger
-- Vervanging: vervang dit bestand voor ander mandaat systeem
-- Afhankelijkheden: 02_tables_core.sql (personen FK)
-- Mandaat types:
--   toegang  — wie mag wat doen
--   gedrag   — hoe gedraagt software zich voor deze eigenaar
--   proces   — tijdelijk procesgebonden (AI personeel)
-- =============================================================

CREATE TABLE IF NOT EXISTS mandaten (
    ulid             TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                             CHECK (is_valid_ulid(ulid)),
    van_persoon_ulid TEXT    NOT NULL REFERENCES personen(ulid),
    naar_type        TEXT    NOT NULL CHECK (naar_type IN (
                                 'persoon', 'klant', 'ai_personeel'
                             )),
    naar_ulid        TEXT    NOT NULL CHECK (is_valid_ulid(naar_ulid)),
    mandaat_type     TEXT    NOT NULL DEFAULT 'toegang'
                             CHECK (mandaat_type IN ('toegang', 'gedrag', 'proces')),
    scope            TEXT    NOT NULL,
    geldig_van       BIGINT  NOT NULL,
    geldig_tot       BIGINT,
    actief           BOOLEAN NOT NULL DEFAULT TRUE,
    -- gedrag_config: softwaregedrag per klant/persoon (verplicht bij type=gedrag)
    gedrag_config    JSONB,
    -- meta: vrije velden per mandaat type
    meta             JSONB
);

-- Gedrag config verplicht voor type=gedrag
CREATE OR REPLACE FUNCTION chk_gedrag_config()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.mandaat_type = 'gedrag' AND NEW.gedrag_config IS NULL THEN
        RAISE EXCEPTION
            'Mandaat % (type=gedrag) vereist gedrag_config', NEW.ulid;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_chk_gedrag_config ON mandaten;
CREATE TRIGGER trg_chk_gedrag_config
    BEFORE INSERT OR UPDATE ON mandaten
    FOR EACH ROW EXECUTE FUNCTION chk_gedrag_config();
