-- ─── CuiperHeader ───────────────────────────────────────────────────────────
-- ULID:          01COMP035CLAUDECTX000000
-- Naam:          ontologie/ClaudeCodeContext.sql
-- Erft via:      CuiperCore → CuiperDonut → CuiperZelfcontroleAI
-- Aangemaakt:    CuiperStapNr 45
-- Gewijzigd:     CuiperStapNr 54 — 2026-04-08
-- ────────────────────────────────────────────────────────────────────────────
-- ClaudeCodeContext.sql
-- Context dump schema voor CuiperZelfcontroleAI
-- Erft via: Cuiper → CuiperCore → CuiperDonut → CuiperZelfcontroleAI → ClaudeCodeContext
--
-- Aangemaakt: CuiperStapNr 45 — ULID: 01JWTFNKN5CONTEXT — 2026-04-07
--
-- Redundantie is toegestaan (data lake model).
-- Elke stap is uniek via DISTINCT (cuiper_stap_nr, ulid).
-- Geen DELETE — alleen INSERT. Amendementen via nieuwe rijen.
--
-- Recursie scope: Cuiper=1 is het anker. Recursie begrensd via recursie_diepte.
-- De serial von Neumann bottleneck: context wordt stap-voor-stap gelezen.
-- Toekomstige uitvinding van Cuiper: niet-serieel model (buiten scope stap 45).

CREATE TABLE IF NOT EXISTS claude_code_context (
    -- Identiteit — elke rij uniek
    ulid                TEXT        NOT NULL,
    cuiper_stap_nr      INTEGER     NOT NULL,
    unix_ms             BIGINT      NOT NULL,   -- servertijd milliseconden
    branch              TEXT        NOT NULL,

    -- Taakcontext — wat doet ClaudeCode op dit moment
    huidige_taak        TEXT,                   -- korte omschrijving huidige taak
    huidige_taak_ulid   TEXT,                   -- ULID van de taak in CuiperBacklog
    context_status      TEXT        DEFAULT 'OK',
      -- OK | DREMPEL_ZACHT | DREMPEL_HARD
    prompt_nr           INTEGER     DEFAULT 0,  -- prompt binnen sessie

    -- Backlog snapshot — toestand op moment van dump
    open_kritiek        INTEGER     DEFAULT 0,
    open_hoog           INTEGER     DEFAULT 0,
    open_medium         INTEGER     DEFAULT 0,
    open_laag           INTEGER     DEFAULT 0,
    wees_count          INTEGER     DEFAULT 0,
    klaar_count         INTEGER     DEFAULT 0,

    -- Recent werk
    laatste_commit      TEXT,                   -- git commit hash
    laatste_commit_msg  TEXT,

    -- Vrije tekst context — wat ClaudeCode weet op dit moment
    context_dump        TEXT,                   -- volledige context als tekst

    -- Keten naar vorige stap (linked list, geen recursie)
    vorige_stap_ulid    TEXT,                   -- NULL voor eerste stap

    -- Recursie scope (Cuiper=Anker als delimiter)
    recursie_diepte     INTEGER     DEFAULT 0,
    recursie_anker      TEXT        DEFAULT 'Cuiper=1',

    -- Sedimentatie
    aangemaakt          BIGINT      NOT NULL,

    -- Garantie: elke CuiperStapNr + ULID combinatie is uniek
    CONSTRAINT distinct_stap_ulid UNIQUE (cuiper_stap_nr, ulid)
);

-- Index op stap_nr voor snel ophalen van laatste stap
CREATE INDEX IF NOT EXISTS idx_context_stap_nr ON claude_code_context (cuiper_stap_nr DESC);
CREATE INDEX IF NOT EXISTS idx_context_ulid ON claude_code_context (ulid);

-- View: laatste context per stap (voor CuiperZelfcontroleAI)
CREATE VIEW IF NOT EXISTS cuiper_laatste_context AS
    SELECT * FROM claude_code_context
    ORDER BY cuiper_stap_nr DESC, aangemaakt DESC
    LIMIT 1;

-- View: contextketen (linked list via vorige_stap_ulid)
-- Recursie begrensd door Cuiper=Anker (max 10 niveaus in applicatiecode)
CREATE VIEW IF NOT EXISTS cuiper_context_keten AS
    SELECT
        ulid,
        cuiper_stap_nr,
        unix_ms,
        huidige_taak,
        context_status,
        vorige_stap_ulid,
        recursie_diepte
    FROM claude_code_context
    ORDER BY cuiper_stap_nr ASC;
