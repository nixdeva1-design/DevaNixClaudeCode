-- CuiperKantoor Schema
-- Alle gevoelige economische data blijft intern (Deva beheer)
-- Klanten zien alleen hun eigen mandaten en processen

-- ============================================================
-- STAP 1: Extensie controles
-- ============================================================

-- btree_gin: GIN indexes op scalaire types (text, int, etc.)
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- pgvector: vector type voor embedding opslag + similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- pg_ulid: native ULID generatie en validatie
-- Controleer of beschikbaar, anders fallback naar text met check constraint
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_available_extensions WHERE name = 'pg_ulid'
    ) THEN
        CREATE EXTENSION IF NOT EXISTS pg_ulid;
        RAISE NOTICE 'pg_ulid extensie geladen — native ULID type beschikbaar';
    ELSE
        RAISE NOTICE 'pg_ulid NIET beschikbaar — ULID opgeslagen als TEXT met validatie';
    END IF;
END;
$$;

-- Controleer of vector extensie correct geladen is
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'vector'
    ) THEN
        RAISE NOTICE 'pgvector geladen — vector type en GIN/IVFFlat/HNSW indexes beschikbaar';
    ELSE
        RAISE WARNING 'pgvector NIET geladen — vector kolommen worden weggelaten';
    END IF;
END;
$$;

-- Controleer of btree_gin geladen is (GIN op scalaire types)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'btree_gin'
    ) THEN
        RAISE NOTICE 'btree_gin geladen — GIN indexes op TEXT/BIGINT/BOOLEAN beschikbaar';
    ELSE
        RAISE WARNING 'btree_gin NIET geladen — GIN indexes op scalaire velden niet beschikbaar';
    END IF;
END;
$$;

-- ============================================================
-- STAP 2: ULID validatie functie (fallback als pg_ulid ontbreekt)
-- ============================================================

CREATE OR REPLACE FUNCTION is_valid_ulid(val TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- ULID: 26 tekens, Crockford Base32 alfabet
    RETURN val ~ '^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================
-- STAP 3: Tabellen (IF NOT EXISTS)
-- ============================================================

CREATE TABLE IF NOT EXISTS personen (
    id              SERIAL PRIMARY KEY,
    kantoor_id      TEXT    NOT NULL DEFAULT 'CuiperKantoor',
    naam            TEXT    NOT NULL,
    rol             TEXT    NOT NULL,
    mandaat_niveau  INTEGER NOT NULL CHECK (mandaat_niveau BETWEEN 1 AND 3),
    actief          BOOLEAN NOT NULL DEFAULT TRUE,
    aangemaakt_op   BIGINT  NOT NULL,
    -- Embedding voor semantisch zoeken op rol/naam (pgvector)
    embedding       vector(1536)
);

CREATE TABLE IF NOT EXISTS klanten (
    id              SERIAL PRIMARY KEY,
    naam            TEXT    NOT NULL,
    actief          BOOLEAN NOT NULL DEFAULT TRUE,
    aangemaakt_op   BIGINT  NOT NULL,
    embedding       vector(1536)
);

CREATE TABLE IF NOT EXISTS omgevingen (
    id              SERIAL PRIMARY KEY,
    naam            TEXT    NOT NULL,
    niveau          INTEGER NOT NULL CHECK (niveau BETWEEN 1 AND 3),
    data_klasse     TEXT    NOT NULL,
    beheer_door     INTEGER REFERENCES personen(id)
);

CREATE TABLE IF NOT EXISTS infrastructuur (
    id              SERIAL PRIMARY KEY,
    naam            TEXT    NOT NULL,
    type            TEXT    NOT NULL CHECK (type IN ('on_premise', 'cloud')),
    provider        TEXT,
    eigenaar        TEXT    NOT NULL,
    gehuurd         BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS mandaten (
    id              SERIAL  PRIMARY KEY,
    ulid            TEXT    UNIQUE NOT NULL
                            CHECK (is_valid_ulid(ulid)),
    van_persoon_id  INTEGER REFERENCES personen(id),
    naar_type       TEXT    NOT NULL CHECK (naar_type IN ('persoon', 'klant', 'ai_personeel')),
    naar_id         INTEGER NOT NULL,
    scope           TEXT    NOT NULL,
    geldig_van      BIGINT  NOT NULL,
    geldig_tot      BIGINT,
    actief          BOOLEAN NOT NULL DEFAULT TRUE,
    meta            JSONB   -- vrije velden per mandaat type
);

CREATE TABLE IF NOT EXISTS processen (
    id              SERIAL  PRIMARY KEY,
    process_ulid    TEXT    UNIQUE NOT NULL
                            CHECK (is_valid_ulid(process_ulid)),
    mandaat_id      INTEGER REFERENCES mandaten(id),
    omgeving_id     INTEGER REFERENCES omgevingen(id),
    agent_type      TEXT    NOT NULL CHECK (agent_type IN ('design', 'implementatie', 'review')),
    start_unix      BIGINT  NOT NULL,
    end_unix        BIGINT,
    tokens_used     BIGINT  NOT NULL DEFAULT 0 CHECK (tokens_used >= 0),
    status          TEXT    NOT NULL DEFAULT 'actief'
                            CHECK (status IN ('actief', 'voltooid', 'mislukt')),
    -- Geen valuta, alleen verbruiksmetriek
    meta            JSONB   -- extra procesparameters
);

-- ============================================================
-- STAP 4: Indexes (GIN + IVFFlat voor vector)
-- ============================================================

-- GIN op process_ulid en mandaat ulid (via btree_gin — zoeken op text)
CREATE INDEX IF NOT EXISTS idx_gin_process_ulid
    ON processen USING GIN (process_ulid gin_trgm_ops)
    WHERE EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm');

-- GIN op mandaten.ulid
CREATE INDEX IF NOT EXISTS idx_gin_mandaat_ulid
    ON mandaten USING GIN (ulid gin_trgm_ops)
    WHERE EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm');

-- GIN op mandaten.meta (JSONB) — doorzoekbaar zonder schema
CREATE INDEX IF NOT EXISTS idx_gin_mandaten_meta
    ON mandaten USING GIN (meta);

-- GIN op processen.meta (JSONB)
CREATE INDEX IF NOT EXISTS idx_gin_processen_meta
    ON processen USING GIN (meta);

-- GIN op personen: zoeken op naam en rol
CREATE INDEX IF NOT EXISTS idx_gin_personen_naam
    ON personen USING GIN (naam, rol);

-- IVFFlat vector index op personen.embedding (pgvector)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE tablename = 'personen' AND indexname = 'idx_vec_personen_embedding'
        ) THEN
            EXECUTE 'CREATE INDEX idx_vec_personen_embedding
                     ON personen USING ivfflat (embedding vector_cosine_ops)
                     WITH (lists = 10)';
            RAISE NOTICE 'IVFFlat vector index aangemaakt op personen.embedding';
        END IF;
    END IF;
END;
$$;

-- ============================================================
-- STAP 5: Diagnostiek — wat is beschikbaar?
-- ============================================================

DO $$
DECLARE
    ext TEXT;
    gevonden BOOLEAN;
BEGIN
    RAISE NOTICE '=== CuiperKantoor Extensie Status ===';
    FOREACH ext IN ARRAY ARRAY['vector','btree_gin','pg_ulid','pg_trgm'] LOOP
        SELECT EXISTS (
            SELECT 1 FROM pg_extension WHERE extname = ext
        ) INTO gevonden;
        IF gevonden THEN
            RAISE NOTICE '  [OK] %', ext;
        ELSE
            RAISE NOTICE '  [--] % (niet geladen)', ext;
        END IF;
    END LOOP;
    RAISE NOTICE '=====================================';
END;
$$;

-- ============================================================
-- STAP 6: Seed data (alleen als tabel leeg is)
-- ============================================================

INSERT INTO personen (naam, rol, mandaat_niveau, aangemaakt_op)
SELECT naam, rol, mandaat_niveau, EXTRACT(EPOCH FROM NOW())::BIGINT
FROM (VALUES
    ('Cuiper',    'Hoofd Architect & Eigenaar', 1),
    ('Deva',      'AI Systeembeheerder',        2),
    ('ClaudeCode','AI Personeel CLI',           3),
    ('Claude.ai', 'AI Personeel Web',           3)
) AS v(naam, rol, mandaat_niveau)
WHERE NOT EXISTS (SELECT 1 FROM personen LIMIT 1);

INSERT INTO omgevingen (naam, niveau, data_klasse, beheer_door)
SELECT naam, niveau, data_klasse, beheer_door
FROM (VALUES
    ('ontwerp',         1, 'geen_productie', 1),
    ('test',            2, 'test',           2),
    ('productie_hoofd', 3, 'productie',      2),
    ('productie_sub',   3, 'productie',      2)
) AS v(naam, niveau, data_klasse, beheer_door)
WHERE NOT EXISTS (SELECT 1 FROM omgevingen LIMIT 1);
