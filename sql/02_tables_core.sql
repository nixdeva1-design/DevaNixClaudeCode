-- =============================================================
-- MODULE 02: Kern tabellen
-- Vervanging: vervang dit bestand voor andere kern entiteiten
-- Afhankelijkheden: 01_functions_core.sql
-- Tabellen: personen, klanten, omgevingen, infrastructuur
-- =============================================================

CREATE TABLE IF NOT EXISTS personen (
    ulid            TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    kantoor_id      TEXT    NOT NULL DEFAULT 'CuiperKantoor',
    naam            TEXT    NOT NULL,
    rol             TEXT    NOT NULL,
    -- 1=volledig (Cuiper), 2=operationeel (Deva), 3=tijdelijk (personeel/AI)
    mandaat_niveau  INTEGER NOT NULL CHECK (mandaat_niveau BETWEEN 1 AND 3),
    actief          BOOLEAN NOT NULL DEFAULT TRUE,
    aangemaakt_op   BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
    embedding       vector(1536)  -- semantisch zoeken op rol/naam
);

CREATE TABLE IF NOT EXISTS klanten (
    ulid            TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    naam            TEXT    NOT NULL,
    actief          BOOLEAN NOT NULL DEFAULT TRUE,
    aangemaakt_op   BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
    embedding       vector(1536)
);

-- Omgevingen: ontwerp → test → productie_hoofd / productie_sub
CREATE TABLE IF NOT EXISTS omgevingen (
    ulid            TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    naam            TEXT    NOT NULL UNIQUE,
    niveau          INTEGER NOT NULL CHECK (niveau BETWEEN 1 AND 3),
    data_klasse     TEXT    NOT NULL
                            CHECK (data_klasse IN (
                                'geen_productie', 'test', 'productie'
                            )),
    beheer_door     TEXT    REFERENCES personen(ulid)
);

-- Infrastructuur: on-premise en cloud resources
CREATE TABLE IF NOT EXISTS infrastructuur (
    ulid            TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    naam            TEXT    NOT NULL,
    type            TEXT    NOT NULL CHECK (type IN ('on_premise', 'cloud')),
    provider        TEXT    CHECK (provider IN (
                                'azure', 'aws', 'gcp', 'kantoor', 'overig'
                            )),
    eigenaar        TEXT    NOT NULL,
    gehuurd         BOOLEAN NOT NULL DEFAULT FALSE,
    aangemaakt_op   BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT
);
