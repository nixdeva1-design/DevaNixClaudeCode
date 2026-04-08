-- 003_CuiperEntiteitenTabel.sql
-- CuiperEntiteitenTabel — elke module, entiteit, component geregistreerd
--
-- Amendement-protocol (wet): nooit DELETE, nooit DROP — alleen INSERT/UPDATE/ALTER ADD
-- Relatie-kolom wet: bestaat kolom niet → aanmaken via cuiper.amendeer_relatie_kolom()
-- GIN index voor full-text zoeken (Nederlands)
--
-- Kolommen:
--   ulid            Primaire sleutel — ULID formaat
--   unix_ts         Aanmaak of laatste wijziging (seconden)
--   naam            Unieke module/entiteit naam (CuiperCamelCase)
--   omschrijving    Korte omschrijving (1 regel)
--   werking         Gedetailleerde werking (meerdere regels toegestaan)
--   status          ACTIEF | WEES | GESEDIMENTEERD | GEBLOKKEERD
--   versie_nr       Semver string: bijv. 0.2.0
--   module_type     script | rust_crate | nix_module | sql_schema | ontologie | datalog | config
--   cuiper_in       Agnostisch input type (komma-gescheiden): none,stdin,args,file,postgres,zenoh,trail,git,hook
--   cuiper_out      Agnostisch output type (komma-gescheiden): none,stdout,stderr,file,postgres,zenoh,trail,git
--   erft_van        Naam van ouder-entiteit (FK naar naam — geen harde FK voor flexibiliteit)
--   taal_syntax_id  FK naar cuiper.taal_syntax.ulid
--   aangemaakt_door CuiperHiveNr als string: bijv. CuiperHiveNr3
--   aangepast_ts    Timestamp laatste UPDATE (seconden)

CREATE SCHEMA IF NOT EXISTS cuiper;

CREATE TABLE IF NOT EXISTS cuiper.entiteiten (
    ulid            TEXT        PRIMARY KEY,
    unix_ts         BIGINT      NOT NULL,
    naam            TEXT        NOT NULL,
    omschrijving    TEXT,
    werking         TEXT,
    status          TEXT        NOT NULL DEFAULT 'ACTIEF',
    versie_nr       TEXT        NOT NULL DEFAULT '0.1.0',
    module_type     TEXT,
    cuiper_in       TEXT        NOT NULL DEFAULT 'none',
    cuiper_out      TEXT        NOT NULL DEFAULT 'none',
    erft_van        TEXT,
    taal_syntax_id  TEXT,
    aangemaakt_door TEXT        NOT NULL DEFAULT 'CuiperHiveNr3',
    aangepast_ts    BIGINT,
    CONSTRAINT entiteiten_naam_unique UNIQUE (naam),
    CONSTRAINT entiteiten_status_check CHECK (
        status IN ('ACTIEF', 'WEES', 'GESEDIMENTEERD', 'GEBLOKKEERD')
    )
);

-- GIN full-text index voor zoeken op naam, omschrijving en werking (Nederlands)
CREATE INDEX IF NOT EXISTS idx_entiteiten_gin
    ON cuiper.entiteiten
    USING GIN (
        to_tsvector('dutch',
            coalesce(naam, '')          || ' ' ||
            coalesce(omschrijving, '')  || ' ' ||
            coalesce(werking, '')
        )
    );

-- Index op unix_ts voor tijdlijn-queries
CREATE INDEX IF NOT EXISTS idx_entiteiten_unix_ts
    ON cuiper.entiteiten (unix_ts DESC);

-- Index op status voor filter-queries
CREATE INDEX IF NOT EXISTS idx_entiteiten_status
    ON cuiper.entiteiten (status);

-- ─── cuiper.amendeer_relatie_kolom ─────────────────────────────────────────
-- Procedure: voeg relatie-kolom toe als die niet bestaat
-- Wet: bestaat een kolom niet voor een relatie → aanmaken
-- Gebruik: CALL cuiper.amendeer_relatie_kolom('verbonden_met', 'TEXT');
CREATE OR REPLACE PROCEDURE cuiper.amendeer_relatie_kolom(
    kolom_naam  TEXT,
    data_type   TEXT DEFAULT 'TEXT'
)
LANGUAGE plpgsql AS $$
DECLARE
    _bestaat BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'cuiper'
          AND table_name   = 'entiteiten'
          AND column_name  = kolom_naam
    ) INTO _bestaat;

    IF NOT _bestaat THEN
        EXECUTE format(
            'ALTER TABLE cuiper.entiteiten ADD COLUMN IF NOT EXISTS %I %s',
            kolom_naam, data_type
        );
        RAISE NOTICE 'Kolom toegevoegd aan cuiper.entiteiten: % (%)', kolom_naam, data_type;
    ELSE
        RAISE NOTICE 'Kolom bestaat al: % — geen wijziging (amendement-protocol)', kolom_naam;
    END IF;
END;
$$;

-- Standaard relatie-kolommen die bij de basisontologie horen
-- Nieuwe relaties → CALL cuiper.amendeer_relatie_kolom('...', 'TEXT');
CALL cuiper.amendeer_relatie_kolom('gebruikt_db',        'TEXT');
CALL cuiper.amendeer_relatie_kolom('publiceert_naar',    'TEXT');
CALL cuiper.amendeer_relatie_kolom('luistert_naar',      'TEXT');
CALL cuiper.amendeer_relatie_kolom('verbonden_met',      'TEXT');
CALL cuiper.amendeer_relatie_kolom('gedocumenteerd_in',  'TEXT');
