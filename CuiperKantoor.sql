-- CuiperKantoor Schema
-- Alle gevoelige economische data blijft intern (Deva beheer)
-- Klanten zien alleen hun eigen mandaten en processen

-- Entiteiten
CREATE TABLE personen (
    id              SERIAL PRIMARY KEY,
    kantoor_id      TEXT NOT NULL DEFAULT 'CuiperKantoor',
    naam            TEXT NOT NULL,
    rol             TEXT NOT NULL,
    mandaat_niveau  INTEGER NOT NULL, -- 1=volledig, 2=operationeel, 3=tijdelijk
    actief          BOOLEAN DEFAULT TRUE,
    aangemaakt_op   BIGINT NOT NULL   -- unix timestamp
);

CREATE TABLE klanten (
    id              SERIAL PRIMARY KEY,
    naam            TEXT NOT NULL,
    actief          BOOLEAN DEFAULT TRUE,
    aangemaakt_op   BIGINT NOT NULL
);

CREATE TABLE omgevingen (
    id              SERIAL PRIMARY KEY,
    naam            TEXT NOT NULL,  -- ontwerp, test, productie_hoofd, productie_sub
    niveau          INTEGER NOT NULL,
    data_klasse     TEXT NOT NULL,
    beheer_door     INTEGER REFERENCES personen(id)
);

CREATE TABLE infrastructuur (
    id              SERIAL PRIMARY KEY,
    naam            TEXT NOT NULL,
    type            TEXT NOT NULL,  -- on_premise, cloud
    provider        TEXT,           -- Microsoft, AWS, Google
    eigenaar        TEXT NOT NULL,  -- CuiperKantoor of klantnaam
    gehuurd         BOOLEAN DEFAULT FALSE
);

-- Mandaat systeem
CREATE TABLE mandaten (
    id              SERIAL PRIMARY KEY,
    ulid            TEXT UNIQUE NOT NULL,
    van_persoon_id  INTEGER REFERENCES personen(id),
    naar_type       TEXT NOT NULL,  -- persoon, klant, ai_personeel
    naar_id         INTEGER NOT NULL,
    scope           TEXT NOT NULL,
    geldig_van      BIGINT NOT NULL,  -- unix timestamp
    geldig_tot      BIGINT,           -- NULL = onbeperkt
    actief          BOOLEAN DEFAULT TRUE
);

-- Processen met kostenbewaking (geen ruwe valuta)
CREATE TABLE processen (
    id              SERIAL PRIMARY KEY,
    process_ulid    TEXT UNIQUE NOT NULL,
    mandaat_id      INTEGER REFERENCES mandaten(id),
    omgeving_id     INTEGER REFERENCES omgevingen(id),
    agent_type      TEXT NOT NULL,  -- design, implementatie
    start_unix      BIGINT NOT NULL,
    end_unix        BIGINT,
    tokens_used     BIGINT DEFAULT 0,
    status          TEXT DEFAULT 'actief'  -- actief, voltooid, mislukt
);

-- Seed data
INSERT INTO personen (naam, rol, mandaat_niveau, aangemaakt_op) VALUES
    ('Cuiper',   'Hoofd Architect & Eigenaar', 1, EXTRACT(EPOCH FROM NOW())::BIGINT),
    ('Deva',     'AI Systeembeheerder',        2, EXTRACT(EPOCH FROM NOW())::BIGINT),
    ('ClaudeCode','AI Personeel CLI',          3, EXTRACT(EPOCH FROM NOW())::BIGINT),
    ('Claude.ai','AI Personeel Web',           3, EXTRACT(EPOCH FROM NOW())::BIGINT);

INSERT INTO omgevingen (naam, niveau, data_klasse, beheer_door) VALUES
    ('ontwerp',          1, 'geen_productie', 1),
    ('test',             2, 'test',           2),
    ('productie_hoofd',  3, 'productie',      2),
    ('productie_sub',    3, 'productie',      2);
