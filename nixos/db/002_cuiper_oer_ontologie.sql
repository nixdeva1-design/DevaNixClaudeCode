-- CuiperOerOntologie — SQL schema
-- Onveranderlijke kern. Alles wat bestaat is een CuiperEntiteit.
-- Gesedimenteerd: 2026-04-05 CuiperStapNr 24
-- ULID sessie: 01JWQNB2K6P8RXWN4LD7HCBDS9T
-- Geen /dev/null — alles is informatie

-- ─── CuiperEntiteit — basis van alles ────────────────────────────────────

CREATE TABLE IF NOT EXISTS cuiper_entiteit (
  ulid          TEXT        PRIMARY KEY,
  nr            TEXT,                          -- positie in hive/topologie
  naam          TEXT        NOT NULL,
  karakter      TEXT,
  archetype     TEXT,
  rol           TEXT,
  functie       TEXT,
  mandaat       TEXT,
  type          TEXT        NOT NULL,          -- software | mens | dier | plant |
                                               -- machine | mineraal | ai | signaal |
                                               -- database | netwerk | cuip | code_regel
  namespace     TEXT,                          -- klant | lab | airgap | agi | systeem
  status        TEXT        DEFAULT 'CAN',     -- CAN | actief | inactief | gearchiveerd
  cuiper_stap_nr INTEGER,
  aangemaakt    TIMESTAMPTZ DEFAULT NOW(),
  gewijzigd     TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Versioning — oud naast nieuw ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS cuiper_versie (
  ulid              TEXT        PRIMARY KEY,
  entiteit_ulid     TEXT        REFERENCES cuiper_entiteit(ulid),
  versie_nr         INTEGER     NOT NULL,
  delta             JSONB,                     -- alleen wat veranderd is
  vorige_versie_ulid TEXT,                     -- referentie naar vorige versie
  reden             TEXT,
  cuiper_stap_nr    INTEGER,
  aangemaakt        TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Verbindingen — alle edges ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS cuiper_verbinding (
  ulid          TEXT        PRIMARY KEY,
  van_ulid      TEXT        REFERENCES cuiper_entiteit(ulid),
  naar_ulid     TEXT        REFERENCES cuiper_entiteit(ulid),
  type          TEXT,                          -- afhankelijkheid | signaal | data |
                                               -- compositie | overerving | vervanging
  richting      TEXT        DEFAULT 'beide',   -- van | naar | beide
  gewicht       FLOAT       DEFAULT 1.0,       -- voor GNN
  namespace     TEXT,
  actief        BOOLEAN     DEFAULT true,
  cuiper_stap_nr INTEGER,
  aangemaakt    TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Cuip — synaps tussen code regels ────────────────────────────────────

CREATE TABLE IF NOT EXISTS cuiper_cuip (
  ulid          TEXT        PRIMARY KEY,
  bestand_ulid  TEXT        REFERENCES cuiper_entiteit(ulid),
  positie       INTEGER     NOT NULL,          -- na welke regel
  status        TEXT        DEFAULT 'CAN',     -- CAN | ontwikkeld | actief
  ontwikkeld_als TEXT,                         -- ULID van ontwikkelde entiteit
  cuiper_stap_nr INTEGER,
  aangemaakt    TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Code regel — elke regel een tupel ───────────────────────────────────

CREATE TABLE IF NOT EXISTS cuiper_code_regel (
  ulid          TEXT        PRIMARY KEY,
  bestand_ulid  TEXT        REFERENCES cuiper_entiteit(ulid),
  module_ulid   TEXT        REFERENCES cuiper_entiteit(ulid),
  regel_nr      INTEGER     NOT NULL,
  inhoud        TEXT,
  type          TEXT,                          -- declaratie | expressie | import |
                                               -- commentaar | cuip_header | config
  ast_node_type TEXT,                          -- AST classificatie
  versie_nr     INTEGER     DEFAULT 1,
  cuiper_stap_nr INTEGER,
  aangemaakt    TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Module registry — elk pakket een node ───────────────────────────────

CREATE TABLE IF NOT EXISTS cuiper_module (
  ulid          TEXT        PRIMARY KEY,
  entiteit_ulid TEXT        REFERENCES cuiper_entiteit(ulid),
  naam          TEXT        NOT NULL,
  type          TEXT,                          -- service | crate | script | config |
                                               -- database | iso | nixmodule
  locatie       TEXT,                          -- pad in repo of poort
  namespace     TEXT,
  poort         INTEGER,
  versie        TEXT,
  hash          TEXT,                          -- inhoud hash voor verificatie
  status        TEXT        DEFAULT 'CAN',
  cuiper_stap_nr INTEGER,
  aangemaakt    TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Amendement log — niets verdwijnt ────────────────────────────────────

CREATE TABLE IF NOT EXISTS cuiper_amendement (
  ulid          TEXT        PRIMARY KEY,
  tabel         TEXT        NOT NULL,
  record_ulid   TEXT,
  voor          JSONB,                         -- staat voor wijziging
  na            JSONB,                         -- staat na wijziging
  reden         TEXT,
  cuiper_stap_nr INTEGER,
  aangemaakt    TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Indexes voor GNN performance ────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_verbinding_van   ON cuiper_verbinding(van_ulid);
CREATE INDEX IF NOT EXISTS idx_verbinding_naar  ON cuiper_verbinding(naar_ulid);
CREATE INDEX IF NOT EXISTS idx_entiteit_type    ON cuiper_entiteit(type);
CREATE INDEX IF NOT EXISTS idx_entiteit_status  ON cuiper_entiteit(status);
CREATE INDEX IF NOT EXISTS idx_module_namespace ON cuiper_module(namespace);
CREATE INDEX IF NOT EXISTS idx_cuip_bestand     ON cuiper_cuip(bestand_ulid);
CREATE INDEX IF NOT EXISTS idx_regel_bestand    ON cuiper_code_regel(bestand_ulid);

-- ─── Basis entiteiten — de hive ───────────────────────────────────────────

INSERT INTO cuiper_entiteit
  (ulid, nr, naam, type, rol, mandaat, status, cuiper_stap_nr)
VALUES
  ('01CUIPER0NUL00000000000000', '0', 'Nul',
   'hive', 'CAN', 'Pure potentie, ademruimte, ongelijk aan null/NaN',
   'CAN', 1),
  ('01CUIPER1CUIPER000000000000', '1', 'Cuiper',
   'mens', 'Architect, uitvinder',
   'Souverein, autonoom, anker, architect, developer, delimiter',
   'actief', 1),
  ('01CUIPER2DEVA0000000000000', '2', 'Deva',
   'mens', 'Login eigenaar',
   'Beheer van de digitale identiteit en toegang',
   'actief', 1),
  ('01CUIPER3CLAUDECODE00000000', '3', 'ClaudeCode',
   'ai', 'Uitvoerende LLM CLI',
   'Uitvoeren van taken op instructie van Cuiper, protocol volgen',
   'actief', 1),
  ('01CUIPER4CLAUDEAI000000000', '4', 'Claude.ai',
   'ai', 'Uitvoerende LLM web',
   'Uitvoeren van taken op instructie van Cuiper via web',
   'actief', 1)
ON CONFLICT (ulid) DO NOTHING;
