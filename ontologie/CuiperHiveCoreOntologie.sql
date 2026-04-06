-- CuiperHiveCoreOntologie.sql
-- Beschrijft UITSLUITEND de leden en componenten van de CuiperHive.
-- Dit is NIET de CuiperOerOntologie (die beschrijft alles wat kan bestaan).
-- Dit is de levende kaart van het hive zelf: wie, wat, hoe verbonden.
--
-- Verbonden aan CuiperListener.sh via trace_id:
--   elke uitvoering van een component genereert een Jaeger trace
--   die trace_id wordt hier opgeslagen als bewijs van uitvoering.
--
-- /dev/null verbod: geen DELETE zonder archivering
-- CuiperStapNr: 34

-- ─── CuiperHiveLid — de vijf leden van de hive ──────────────────────────────

CREATE TABLE IF NOT EXISTS cuiper_hive_lid (
    hive_nr         INTEGER     PRIMARY KEY,   -- 0=Nul, 1=Cuiper, 2=Deva, 3=ClaudeCode, 4=Claude.ai
    naam            TEXT        NOT NULL,
    rol             TEXT        NOT NULL,
    mandaat         TEXT        NOT NULL,
    karakter        TEXT,
    archetype       TEXT,
    status          TEXT        DEFAULT 'actief',  -- actief | CAN | inactief
    ulid            TEXT        UNIQUE NOT NULL,
    aangemaakt      BIGINT      NOT NULL,           -- unix timestamp
    gewijzigd       BIGINT      NOT NULL
);

-- Vaste hive leden — nooit verwijderen, alleen amenderen
INSERT INTO cuiper_hive_lid VALUES
(0, 'Nul',       'CAN — ademruimte voor potentie',       'Nulpunt van het systeem. Ongelijk aan null, ongelijk aan NaN.',
 'Stille aanwezigheid', 'Nulpunt',   'actief', '01HIVE00NUL0000000000000000', 0, 0),
(1, 'Cuiper',    'Architect, uitvinder, delimiter',       'Souverein, autonoom, anker. Eerste principes. Radicale logica.',
 'Analytisch, doelgericht', 'Architect', 'actief', '01HIVE01CUIPER000000000000', 0, 0),
(2, 'Deva',      'Login eigenaar, operator',              'Eigenaar van de runtime. Voert uit wat Cuiper ontwerpt.',
 'Praktisch, direct',   'Operator',  'actief', '01HIVE02DEVA0000000000000000', 0, 0),
(3, 'ClaudeCode','Uitvoerende LLM (CLI)',                 'Schrijven, committen, pushen, vastleggen. Bouwt op instructie.',
 'Uitvoerend, nauwkeurig', 'Uitvoerder', 'actief', '01HIVE03CLAUDECODE00000000', 0, 0),
(4, 'Claude.ai', 'Uitvoerende LLM (web)',                 'Ontwerpen, redeneren, adviseren. Geen directe disk-toegang.',
 'Ontwerper, redenaar',  'Adviseur',  'actief', '01HIVE04CLAUDEWEB000000000', 0, 0)
ON CONFLICT (hive_nr) DO UPDATE SET
    gewijzigd = EXCLUDED.gewijzigd;

-- ─── CuiperHiveComponent — alle software-componenten van de hive ─────────────

CREATE TABLE IF NOT EXISTS cuiper_hive_component (
    ulid            TEXT        PRIMARY KEY,
    naam            TEXT        NOT NULL,
    type            TEXT        NOT NULL,
      -- script | nix-module | rust-crate | sql-schema | config | ontologie
    pad             TEXT,                       -- bestandspad relatief aan repo root
    beschrijving    TEXT,
    eigenaar_hive_nr INTEGER    REFERENCES cuiper_hive_lid(hive_nr),
    status          TEXT        DEFAULT 'actief',
    aangemaakt_stap INTEGER,                    -- CuiperStapNr waarop aangemaakt
    aangemaakt      BIGINT      NOT NULL,
    gewijzigd       BIGINT      NOT NULL
);

-- ─── CuiperHiveVerbinding — relaties tussen componenten ─────────────────────

CREATE TABLE IF NOT EXISTS cuiper_hive_verbinding (
    ulid            TEXT        PRIMARY KEY,
    van_ulid        TEXT        REFERENCES cuiper_hive_component(ulid),
    naar_ulid       TEXT        REFERENCES cuiper_hive_component(ulid),
    type            TEXT        NOT NULL,
      -- gebruikt | roept-aan | produceert | configureert | bewaakt | tracet
    beschrijving    TEXT,
    aangemaakt      BIGINT      NOT NULL
);

-- ─── CuiperListenerTrace — uitvoeringshistorie via CuiperListener.sh ────────
-- Elke keer dat CuiperListener.sh een component uitvoert, komt hier een rij.
-- trace_id linkt naar Jaeger voor de volledige span-boom.

CREATE TABLE IF NOT EXISTS cuiper_listener_trace (
    ulid            TEXT        PRIMARY KEY,
    component_ulid  TEXT        REFERENCES cuiper_hive_component(ulid),
    trace_id        TEXT        NOT NULL,       -- Jaeger trace ID (32 hex)
    span_id         TEXT        NOT NULL,       -- Jaeger span ID (16 hex)
    stap_nr         INTEGER,
    exit_code       INTEGER     NOT NULL,
    duur_seconden   INTEGER,
    markov_uitkomst TEXT,                       -- C==B (succes) | C!=B (rollback)
    uitgevoerd      BIGINT      NOT NULL        -- unix timestamp
);

-- ─── Initiele componenten — de bekende hive onderdelen ───────────────────────

INSERT INTO cuiper_hive_component (ulid, naam, type, pad, beschrijving, eigenaar_hive_nr, aangemaakt_stap, aangemaakt, gewijzigd)
VALUES
('01COMP001LISTENER000000000', 'CuiperListener',     'script',    'scripts/protocol/CuiperListener.sh',
 'Uitvoeringsomgeving met Jaeger tracing. Geen directe uitvoering zonder listener.',     3, 34, 0, 0),
('01COMP002COUNTER0000000000', 'CuiperPromptCounter','script',    'scripts/protocol/CuiperPromptCounter.sh',
 'Dynamische context-drempel bewaking. Auto-commit trail logs.',                         3, 31, 0, 0),
('01COMP003KLAAR00000000000', 'CuiperKlaarMelding',  'script',    'scripts/protocol/CuiperKlaarMelding.sh',
 'Verplichte afsluiting elke respons. Toont backlog + drempel status.',                  3, 32, 0, 0),
('01COMP004BACKLOG000000000', 'CuiperBacklogPlanner','script',    'scripts/protocol/CuiperBacklogPlanner.sh',
 'Taakbeheer: toevoegen, status, prioriteit, samenvatting.',                             3, 30, 0, 0),
('01COMP005STEWARD000000000', 'CuiperSteward',       'script',    'scripts/protocol/CuiperSteward.sh',
 'Sessie continuïteit: open, sluit, herstel.',                                           3, 24, 0, 0),
('01COMP006SENTINEL00000000', 'CuiperSentinel',      'script',    'scripts/protocol/CuiperSentinel.sh',
 'Automatisch opslaan bij interrupt, stroomuitval, SIGTERM.',                            3, 24, 0, 0),
('01COMP007PORTS00000000000', 'CuiperPorts',         'nix-module','nixos/modules/CuiperPorts.nix',
 'Centrale poortregistry. Enige bron van waarheid voor alle poorten.',                   1, 19, 0, 0),
('01COMP008SERVICES0000000', 'CuiperServices',       'nix-module','nixos/modules/CuiperServices.nix',
 'Alle services opt-in via enable optie.',                                               1, 33, 0, 0),
('01COMP009DATABASES000000', 'CuiperDatabases',      'nix-module','nixos/modules/CuiperDatabases.nix',
 'Alle databases opt-in via enable optie.',                                              1, 33, 0, 0),
('01COMP010JAEGER00000000', 'CuiperJaeger',          'nix-module','nixos/modules/CuiperJaeger.nix',
 'Jaeger all-in-one. OTLP HTTP op poort 4318.',                                          1, 34, 0, 0),
('01COMP011CORE00000000000', 'cuiper-core',           'rust-crate','crates/cuiper-core/',
 'Kern types: CuiperEntiteit, CuiperHive, CuiperMarkov, CuiperMandaat.',                1, 33, 0, 0),
('01COMP012DATALOG0000000', 'cuiper-datalog',         'rust-crate','crates/cuiper-datalog/',
 'Forward chaining Datalog engine. Geen Java.',                                          1, 33, 0, 0),
('01COMP013BUS000000000000', 'cuiper-bus',            'rust-crate','crates/cuiper-bus/',
 'Zenoh namespace wrapper met isolatie per klant/lab/airgap/agi.',                       1, 33, 0, 0),
('01COMP014CONFIG000000000', 'CuiperConfig',          'config',   'CuiperConfig.env',
 'Centrale config. Alle scripts sourcen dit. Geen hardcoded paden.',                     1, 33, 0, 0),
('01COMP015ONTOLOGIE000000', 'CuiperHiveCoreOntologie','sql-schema','ontologie/CuiperHiveCoreOntologie.sql',
 'Levende kaart van het hive: leden, componenten, verbindingen, traces.',                1, 34, 0, 0)
ON CONFLICT (ulid) DO NOTHING;

-- ─── Verbindingen — CuiperListener is verbonden aan alles ────────────────────

INSERT INTO cuiper_hive_verbinding (ulid, van_ulid, naar_ulid, type, beschrijving, aangemaakt)
VALUES
('01VBND001', '01COMP001LISTENER000000000', '01COMP010JAEGER00000000',  'tracet',      'Stuurt OTLP spans naar Jaeger', 0),
('01VBND002', '01COMP001LISTENER000000000', '01COMP014CONFIG000000000', 'configureert','Leest CUIPER_JAEGER_OTLP_URL',  0),
('01VBND003', '01COMP002COUNTER0000000000', '01COMP001LISTENER000000000','roept-aan',  'Counter triggert listener via stop hook', 0),
('01VBND004', '01COMP011CORE00000000000',   '01COMP012DATALOG0000000',  'gebruikt',   'Core types gebruikt door datalog engine', 0),
('01VBND005', '01COMP013BUS000000000000',   '01COMP011CORE00000000000', 'gebruikt',   'Bus gebruikt core CuiperSignaal types', 0)
ON CONFLICT (ulid) DO NOTHING;
