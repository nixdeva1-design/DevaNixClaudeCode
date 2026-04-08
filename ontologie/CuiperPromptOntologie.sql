-- ─── CuiperHeader ───────────────────────────────────────────────────────────
-- ULID:          01COMP036PROMPTSQL000000
-- Naam:          ontologie/CuiperPromptOntologie.sql
-- Erft via:      CuiperCore → CuiperDonut → CuiperPromptExportOperator
-- Aangemaakt:    CuiperStapNr 53
-- Gewijzigd:     CuiperStapNr 54 — 2026-04-08
-- ────────────────────────────────────────────────────────────────────────────
-- CuiperPromptOntologie.sql
-- SQLite / DuckDB compatibel basisschema
-- Erft via: Cuiper → CuiperCore → CuiperDonut → CuiperPromptExportOperator
--
-- CuiperStapNr: 53  ULID: 01KNN8GN4Z9CPS2V9E5RRWQC59
-- Aangemaakt:    2026-04-08
-- Wet:           Geen DELETE. Alleen INSERT. Amendementen via nieuwe rijen.
-- /dev/null verbod: elke fout bij inladen gaat naar trail log, nooit stil weggegooid.
--
-- Drie tabellen per prompt-triplet:
--   cuiper_vraag_prompt        → input van Cuiper/Deva (CuiperHiveNr 1/2)
--   cuiper_beredenering_prompt → interne redenering van ClaudeCode (CuiperHiveNr 3)
--   cuiper_antwoord_prompt     → output richting Cuiper/Deva, incl. nabeschouwing/fout
--
-- Markov keten per triplet: A=staat_voor, B=verwacht, C=werkelijk
--   Als C == B → SUCCES
--   Als C != B → ROLLBACK (rollbackpunt = git commit hash)
--
-- Laadopdracht (DuckDB):
--   duckdb cuiper.duckdb < ontologie/CuiperPromptOntologie.sql
-- Laadopdracht (SQLite):
--   sqlite3 cuiper.sqlite < ontologie/CuiperPromptOntologie.sql

-- ─── cuiper_vraag_prompt ─────────────────────────────────────────────────────
-- Elke gebruikersvraag of instructie aan ClaudeCode.

CREATE TABLE IF NOT EXISTS cuiper_vraag_prompt (
    ulid                TEXT        PRIMARY KEY,
    cuiper_stap_nr      INTEGER     NOT NULL,
    sessie_ulid         TEXT        NOT NULL,    -- sessie ID (.jsonl bestandsnaam)
    unix_ms             BIGINT      NOT NULL,    -- servertijd milliseconden
    branch              TEXT        NOT NULL,    -- git branch op moment van vraag
    hive_nr_van         INTEGER     NOT NULL DEFAULT 2,   -- 1=Cuiper 2=Deva
    hive_nr_naar        INTEGER     NOT NULL DEFAULT 3,   -- altijd ClaudeCode (3)
    tekst               TEXT        NOT NULL,    -- de volledige vraag/instructie
    bron                TEXT        DEFAULT 'session-jsonl',
      -- session-jsonl | session-live | conversation-summary | stop-hook
    is_ci_notitie       INTEGER     DEFAULT 0,   -- 1 als ci:: of CI:: prefix
    aangemaakt          BIGINT      NOT NULL,

    CONSTRAINT distinct_vraag_stap_ulid UNIQUE (cuiper_stap_nr, ulid)
);

CREATE INDEX IF NOT EXISTS idx_vraag_stap_nr   ON cuiper_vraag_prompt (cuiper_stap_nr DESC);
CREATE INDEX IF NOT EXISTS idx_vraag_sessie    ON cuiper_vraag_prompt (sessie_ulid);
CREATE INDEX IF NOT EXISTS idx_vraag_unix_ms   ON cuiper_vraag_prompt (unix_ms DESC);

-- ─── cuiper_beredenering_prompt ──────────────────────────────────────────────
-- De interne redenering van ClaudeCode: plan, Markov-transitie, rollbackpunt.

CREATE TABLE IF NOT EXISTS cuiper_beredenering_prompt (
    ulid                TEXT        PRIMARY KEY,
    vraag_ulid          TEXT        NOT NULL REFERENCES cuiper_vraag_prompt(ulid),
    cuiper_stap_nr      INTEGER     NOT NULL,
    sessie_ulid         TEXT        NOT NULL,
    unix_ms             BIGINT      NOT NULL,

    -- Inhoud
    redenering          TEXT,        -- vrijeschrift redenering (kan leeg zijn bij compaction)
    plan                TEXT,        -- stappenplan als tekst

    -- Markov Cuiper3MarkovchainProtocol
    markov_a            TEXT,        -- CuiperStatusBackup{n}: huidige stabiele staat
    markov_b            TEXT,        -- CuiperVerwachtBackup{n}: verwachte staat
    markov_c            TEXT,        -- CuiperNaVerwachtBackup{n}: werkelijke staat
    markov_uitkomst     TEXT,        -- 'C==B' (succes) | 'C!=B' (rollback)
    rollbackpunt        TEXT,        -- git commit hash voor rollback

    -- Gereedschap gebruikt
    tools_gebruikt      TEXT,        -- kommalijst: Read,Edit,Bash,Grep...

    aangemaakt          BIGINT       NOT NULL,

    CONSTRAINT distinct_beredenering_stap_ulid UNIQUE (cuiper_stap_nr, ulid)
);

CREATE INDEX IF NOT EXISTS idx_bered_stap_nr   ON cuiper_beredenering_prompt (cuiper_stap_nr DESC);
CREATE INDEX IF NOT EXISTS idx_bered_vraag     ON cuiper_beredenering_prompt (vraag_ulid);
CREATE INDEX IF NOT EXISTS idx_bered_uitkomst  ON cuiper_beredenering_prompt (markov_uitkomst);

-- ─── cuiper_antwoord_prompt ──────────────────────────────────────────────────
-- De output van ClaudeCode richting Cuiper/Deva.
-- Bevat nabeschouwing (succes) of foutverklaring (fout/rollback).

CREATE TABLE IF NOT EXISTS cuiper_antwoord_prompt (
    ulid                    TEXT        PRIMARY KEY,
    vraag_ulid              TEXT        NOT NULL REFERENCES cuiper_vraag_prompt(ulid),
    beredenering_ulid       TEXT        REFERENCES cuiper_beredenering_prompt(ulid),
    cuiper_stap_nr          INTEGER     NOT NULL,
    sessie_ulid             TEXT        NOT NULL,
    unix_ms                 BIGINT      NOT NULL,

    -- Antwoordinhoud
    tekst                   TEXT        NOT NULL,    -- het volledige antwoord
    uitkomst                TEXT        NOT NULL DEFAULT 'SUCCES',
      -- SUCCES | FOUT | ROLLBACK | GEDEELTELIJK

    -- Bij SUCCES: nabeschouwing — waarom deze keuze uit welke opties
    nabeschouwing           TEXT,
    gekozen_optie           TEXT,        -- de gekozen aanpak
    afgewezen_opties        TEXT,        -- alternatieven en reden van afwijzing

    -- Bij FOUT / ROLLBACK: verklaring
    fout_code               TEXT,        -- exit code of error type
    fout_melding            TEXT,        -- volledige foutmelding (nooit afgekapt)
    fout_locatie            TEXT,        -- bestand:regel of script:functie
    conflict_beschrijving   TEXT,        -- conflicten tijdens uitvoering
    herstel_actie           TEXT,        -- wat is gedaan om te herstellen

    -- Sedimentatie
    aangemaakt              BIGINT      NOT NULL,

    CONSTRAINT distinct_antwoord_stap_ulid UNIQUE (cuiper_stap_nr, ulid)
);

CREATE INDEX IF NOT EXISTS idx_antw_stap_nr    ON cuiper_antwoord_prompt (cuiper_stap_nr DESC);
CREATE INDEX IF NOT EXISTS idx_antw_vraag      ON cuiper_antwoord_prompt (vraag_ulid);
CREATE INDEX IF NOT EXISTS idx_antw_uitkomst   ON cuiper_antwoord_prompt (uitkomst);

-- ─── View: volledige prompt-triplet ─────────────────────────────────────────
-- Elke stap als één rij: vraag + redenering + antwoord samengevoegd.

CREATE VIEW IF NOT EXISTS cuiper_prompt_triplet AS
    SELECT
        v.cuiper_stap_nr,
        v.ulid               AS vraag_ulid,
        v.unix_ms            AS vraag_unix_ms,
        v.tekst              AS vraag_tekst,
        v.bron               AS vraag_bron,
        b.ulid               AS beredenering_ulid,
        b.redenering         AS beredenering_tekst,
        b.plan               AS plan,
        b.markov_uitkomst    AS markov_uitkomst,
        b.rollbackpunt       AS rollbackpunt,
        a.ulid               AS antwoord_ulid,
        a.tekst              AS antwoord_tekst,
        a.uitkomst           AS uitkomst,
        a.nabeschouwing      AS nabeschouwing,
        a.fout_code          AS fout_code,
        a.fout_melding       AS fout_melding
    FROM cuiper_vraag_prompt v
    LEFT JOIN cuiper_beredenering_prompt b ON b.vraag_ulid = v.ulid
    LEFT JOIN cuiper_antwoord_prompt     a ON a.vraag_ulid = v.ulid
    ORDER BY v.cuiper_stap_nr ASC;
