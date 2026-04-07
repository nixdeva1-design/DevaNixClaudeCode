-- =============================================================
-- MODULE 06: Processen tabel + mandaat trigger
-- Vervanging: vervang dit bestand voor ander proces tracking model
-- Afhankelijkheden: 04_tables_mandaten.sql, 02_tables_core.sql, 03_tables_devices.sql
-- Kernregel: elk proces vereist altijd een actief mandaat (ULID lookup verplicht)
-- =============================================================

CREATE TABLE IF NOT EXISTS processen (
    -- process_ulid is de canonieke ID die door het hele systeem reist
    process_ulid  TEXT    PRIMARY KEY
                          CHECK (is_valid_ulid(process_ulid)),

    -- VERPLICHTE mandaat lookup — geen proces zonder actief mandaat
    mandaat_ulid  TEXT    NOT NULL REFERENCES mandaten(ulid),

    omgeving_ulid TEXT    NOT NULL REFERENCES omgevingen(ulid),
    device_ulid   TEXT    NOT NULL REFERENCES devices(ulid),

    agent_type    TEXT    NOT NULL CHECK (agent_type IN (
                              'design', 'implementatie', 'review'
                          )),

    -- Proceskosten (geen valuta — alleen verbruiksmetriek)
    start_unix    BIGINT  NOT NULL,
    end_unix      BIGINT,
    tokens_used   BIGINT  NOT NULL DEFAULT 0 CHECK (tokens_used >= 0),

    status        TEXT    NOT NULL DEFAULT 'actief'
                          CHECK (status IN ('actief', 'voltooid', 'mislukt')),
    meta          JSONB,

    CONSTRAINT chk_tijdvolgorde
        CHECK (end_unix IS NULL OR end_unix >= start_unix)
);

-- Proces mag niet starten zonder actief mandaat op start tijdstip
CREATE OR REPLACE FUNCTION chk_mandaat_actief()
RETURNS TRIGGER AS $$
BEGIN
    -- Cuiper bypast alle checks
    IF is_cuiper(
        (SELECT naar_ulid FROM mandaten WHERE ulid = NEW.mandaat_ulid LIMIT 1)
    ) THEN
        RETURN NEW;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM mandaten
        WHERE ulid       = NEW.mandaat_ulid
          AND actief     = TRUE
          AND geldig_van <= NEW.start_unix
          AND (geldig_tot IS NULL OR geldig_tot >= NEW.start_unix)
    ) THEN
        RAISE EXCEPTION
            'Proces % heeft geen actief mandaat op start tijdstip (mandaat_ulid: %)',
            NEW.process_ulid, NEW.mandaat_ulid;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_chk_mandaat_actief ON processen;
CREATE TRIGGER trg_chk_mandaat_actief
    BEFORE INSERT OR UPDATE ON processen
    FOR EACH ROW EXECUTE FUNCTION chk_mandaat_actief();
