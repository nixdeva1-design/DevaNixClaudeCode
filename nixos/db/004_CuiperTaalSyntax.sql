-- 004_CuiperTaalSyntax.sql
-- CuiperTaalSyntax — precisie-vocabulaire van CuiperHive
-- Elke term heeft één betekenis. Geen overlap. Geen aanname.
-- Bron: CLAUDE.md § CuiperVocabulaire
--
-- Amendement-protocol: nooit DELETE/DROP — INSERT ON CONFLICT DO UPDATE
-- GIN index voor full-text zoeken

CREATE SCHEMA IF NOT EXISTS cuiper;

CREATE TABLE IF NOT EXISTS cuiper.taal_syntax (
    ulid             TEXT    PRIMARY KEY,
    unix_ts          BIGINT  NOT NULL,
    term             TEXT    NOT NULL,
    definitie        TEXT    NOT NULL,
    wat_ik_doe       TEXT,           -- feitelijke actie (1 regel)
    externe_state    TEXT,           -- Nee | Lokale disk | Lokale git | Remote | OS runtime | OS + extern
    overleeft_sessie TEXT,           -- Ja | Nee | Tot commit | Tot push | Tot reboot
    status           TEXT    NOT NULL DEFAULT 'ACTIEF',
    versie_nr        TEXT    NOT NULL DEFAULT '0.1.0',
    aangemaakt_door  TEXT    NOT NULL DEFAULT 'CuiperHiveNr3',
    aangepast_ts     BIGINT,
    CONSTRAINT taal_syntax_term_unique UNIQUE (term),
    CONSTRAINT taal_syntax_status_check CHECK (
        status IN ('ACTIEF', 'GESEDIMENTEERD', 'WEES', 'GEBLOKKEERD')
    )
);

-- GIN full-text index
CREATE INDEX IF NOT EXISTS idx_taal_syntax_gin
    ON cuiper.taal_syntax
    USING GIN (
        to_tsvector('dutch',
            coalesce(term, '')       || ' ' ||
            coalesce(definitie, '')  || ' ' ||
            coalesce(wat_ik_doe, '')
        )
    );

CREATE INDEX IF NOT EXISTS idx_taal_syntax_unix_ts
    ON cuiper.taal_syntax (unix_ts DESC);
