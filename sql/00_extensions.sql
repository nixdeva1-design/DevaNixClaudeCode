-- =============================================================
-- MODULE 00: Extensies
-- Vervanging: vervang dit bestand als je andere extensies nodig hebt
-- Afhankelijkheden: geen
-- =============================================================

-- GIN indexes op scalaire types (text, int, bool)
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- Trigram matching — vereist voor GIN op ULID tekstvelden
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- pgvector — vector type voor embedding opslag en similarity search
CREATE EXTENSION IF NOT EXISTS vector;

-- pg_ulid — optioneel, native ULID generatie
-- Fallback in module 01 als niet aanwezig
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_available_extensions WHERE name = 'pg_ulid'
    ) THEN
        CREATE EXTENSION IF NOT EXISTS pg_ulid;
        RAISE NOTICE '[OK] pg_ulid geladen';
    ELSE
        RAISE NOTICE '[--] pg_ulid niet beschikbaar — fallback actief in module 01';
    END IF;
END;
$$;

-- Diagnostiek: toon geladen extensies
DO $$
DECLARE
    ext      TEXT;
    geladen  BOOLEAN;
BEGIN
    RAISE NOTICE '=== CuiperKantoor Extensie Status ===';
    FOREACH ext IN ARRAY ARRAY['vector','btree_gin','pg_trgm','pg_ulid'] LOOP
        SELECT EXISTS (
            SELECT 1 FROM pg_extension WHERE extname = ext
        ) INTO geladen;
        RAISE NOTICE '  %  %',
            CASE WHEN geladen THEN '[OK]' ELSE '[--]' END, ext;
    END LOOP;
    RAISE NOTICE '=====================================';
END;
$$;
