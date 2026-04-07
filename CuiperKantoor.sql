-- CuiperKantoor Schema
-- ULID is de canonieke identifier — reist mee per proces
-- Alle FK relaties via ULID, geen SERIAL integers als referentie
-- Klanten zien alleen hun eigen mandaten en processen

-- ============================================================
-- STAP 1: Extensie controles
-- ============================================================

CREATE EXTENSION IF NOT EXISTS btree_gin;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_ulid') THEN
        CREATE EXTENSION IF NOT EXISTS pg_ulid;
        RAISE NOTICE '[OK] pg_ulid — native ULID type beschikbaar';
    ELSE
        RAISE NOTICE '[--] pg_ulid niet beschikbaar — fallback: TEXT + is_valid_ulid()';
    END IF;
END;
$$;

DO $$
DECLARE ext TEXT;
        gevonden BOOLEAN;
BEGIN
    RAISE NOTICE '=== CuiperKantoor Extensie Status ===';
    FOREACH ext IN ARRAY ARRAY['vector','btree_gin','pg_trgm','pg_ulid'] LOOP
        SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = ext) INTO gevonden;
        RAISE NOTICE '  %  %', CASE WHEN gevonden THEN '[OK]' ELSE '[--]' END, ext;
    END LOOP;
    RAISE NOTICE '=====================================';
END;
$$;

-- ============================================================
-- STAP 2: ULID hulpfuncties
-- ============================================================

-- Validatie (fallback als pg_ulid ontbreekt)
CREATE OR REPLACE FUNCTION is_valid_ulid(val TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN val ~ '^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Genereer ULID via pg_ulid of via uuid fallback
CREATE OR REPLACE FUNCTION gen_ulid()
RETURNS TEXT AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_ulid') THEN
        RETURN gen_ulid();  -- native pg_ulid functie
    ELSE
        -- Fallback: tijdstempel prefix + random suffix (Crockford Base32 subset)
        RETURN upper(
            lpad(to_hex(EXTRACT(EPOCH FROM clock_timestamp())::BIGINT * 1000), 10, '0') ||
            replace(replace(replace(
                encode(gen_random_bytes(10), 'base64'),
                '+',''), '/', ''), '=', '')
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- STAP 3: God rechten helper — Cuiper bypast alle checks
-- ============================================================

-- Geeft TRUE als de actor Cuiper is (mandaat_niveau=1)
-- Alle triggers controleren dit eerst — Cuiper wordt nooit geblokkeerd
CREATE OR REPLACE FUNCTION is_cuiper(actor_ulid TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM personen
        WHERE ulid = actor_ulid
          AND mandaat_niveau = 1
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Geeft TRUE als actor Cuiper of Deva is (niveau <= 2)
CREATE OR REPLACE FUNCTION is_beheerder(actor_ulid TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM personen
        WHERE ulid = actor_ulid
          AND mandaat_niveau <= 2
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- STAP 4: Tabellen met ULID als primaire sleutel
-- ============================================================

CREATE TABLE IF NOT EXISTS personen (
    ulid            TEXT    PRIMARY KEY DEFAULT gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    kantoor_id      TEXT    NOT NULL DEFAULT 'CuiperKantoor',
    naam            TEXT    NOT NULL,
    rol             TEXT    NOT NULL,
    mandaat_niveau  INTEGER NOT NULL CHECK (mandaat_niveau BETWEEN 1 AND 3),
    actief          BOOLEAN NOT NULL DEFAULT TRUE,
    aangemaakt_op   BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
    embedding       vector(1536)
);

CREATE TABLE IF NOT EXISTS klanten (
    ulid            TEXT    PRIMARY KEY DEFAULT gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    naam            TEXT    NOT NULL,
    actief          BOOLEAN NOT NULL DEFAULT TRUE,
    aangemaakt_op   BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
    embedding       vector(1536)
);

CREATE TABLE IF NOT EXISTS omgevingen (
    ulid            TEXT    PRIMARY KEY DEFAULT gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    naam            TEXT    NOT NULL UNIQUE,
    niveau          INTEGER NOT NULL CHECK (niveau BETWEEN 1 AND 3),
    data_klasse     TEXT    NOT NULL,
    beheer_door     TEXT    REFERENCES personen(ulid)  -- FK via ULID
);

CREATE TABLE IF NOT EXISTS infrastructuur (
    ulid            TEXT    PRIMARY KEY DEFAULT gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    naam            TEXT    NOT NULL,
    type            TEXT    NOT NULL CHECK (type IN ('on_premise', 'cloud')),
    provider        TEXT,
    eigenaar        TEXT    NOT NULL,
    gehuurd         BOOLEAN NOT NULL DEFAULT FALSE
);

-- Devices: elke fysieke of virtuele machine
-- eigenaar_type bepaalt of het kantoor of klant eigendom is
CREATE TABLE IF NOT EXISTS devices (
    ulid              TEXT    PRIMARY KEY DEFAULT gen_ulid()
                              CHECK (is_valid_ulid(ulid)),
    naam              TEXT    NOT NULL,
    type              TEXT    NOT NULL CHECK (type IN ('laptop', 'server', 'cloud_vm')),
    eigenaar_type     TEXT    NOT NULL CHECK (eigenaar_type IN ('kantoor', 'klant')),
    eigenaar_ulid     TEXT    NOT NULL CHECK (is_valid_ulid(eigenaar_ulid)),

    -- Netwerk identiteit
    mac_adres         TEXT    UNIQUE,  -- primaire hardware identifier

    -- Vaste standplaats (thuislocatie van het device)
    standplaats       TEXT,            -- adres of beschrijving
    standplaats_lat   NUMERIC(10, 7),  -- GPS breedtegraad standplaats
    standplaats_lon   NUMERIC(10, 7),  -- GPS lengtegraad standplaats

    -- Laatste bekende GPS positie (live/polling)
    gps_lat           NUMERIC(10, 7),
    gps_lon           NUMERIC(10, 7),
    gps_bijgewerkt_op BIGINT,          -- unix timestamp laatste GPS update

    -- Eigen cloud
    eigen_cloud       BOOLEAN NOT NULL DEFAULT FALSE,
    cloud_provider    TEXT    CHECK (
                          cloud_provider IS NULL OR
                          cloud_provider IN ('azure', 'aws', 'gcp', 'overig')
                      ),

    -- Status en diefstal
    actief            BOOLEAN NOT NULL DEFAULT TRUE,
    gestolen          BOOLEAN NOT NULL DEFAULT FALSE,
    gestolen_gemeld_op BIGINT,
    ontkoppeld_op     BIGINT,          -- tijdstip remote ontkoppeling
    ontkoppeld_door   TEXT    REFERENCES personen(ulid),  -- wie ontkoppelde

    aangemaakt_op     BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,

    CONSTRAINT chk_cloud_provider CHECK (
        (eigen_cloud = FALSE AND cloud_provider IS NULL) OR
        (eigen_cloud = TRUE  AND cloud_provider IS NOT NULL)
    ),
    CONSTRAINT chk_gestolen_tijdstip CHECK (
        (gestolen = FALSE) OR
        (gestolen = TRUE AND gestolen_gemeld_op IS NOT NULL)
    )
);

-- Software producten die CuiperKantoor levert
CREATE TABLE IF NOT EXISTS software_producten (
    ulid            TEXT    PRIMARY KEY DEFAULT gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    naam            TEXT    NOT NULL,
    versie          TEXT    NOT NULL,
    actief          BOOLEAN NOT NULL DEFAULT TRUE,
    aangemaakt_op   BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT
);

-- Mandaten uitgebreid met type:
--   toegang  — wie mag wat doen (bestaand)
--   gedrag   — hoe gedraagt de software zich voor deze eigenaar
--   proces   — tijdelijk procesgebonden (AI personeel)
--
-- gedrag_config (JSONB) bevat de gedragsregels per product per klant/persoon
-- Klanten zien alleen hun eigen gedrag_config — nooit die van anderen
ALTER TABLE mandaten
    ADD COLUMN IF NOT EXISTS mandaat_type TEXT NOT NULL DEFAULT 'toegang'
        CHECK (mandaat_type IN ('toegang', 'gedrag', 'proces')),
    ADD COLUMN IF NOT EXISTS gedrag_config JSONB;

-- Gedrag config is verplicht voor type=gedrag
CREATE OR REPLACE FUNCTION chk_gedrag_config()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.mandaat_type = 'gedrag' AND NEW.gedrag_config IS NULL THEN
        RAISE EXCEPTION
            'Mandaat % is type=gedrag maar heeft geen gedrag_config',
            NEW.ulid;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_chk_gedrag_config ON mandaten;
CREATE TRIGGER trg_chk_gedrag_config
    BEFORE INSERT OR UPDATE ON mandaten
    FOR EACH ROW EXECUTE FUNCTION chk_gedrag_config();

-- Licenties: zowel personen (personeel) als klanten
-- eigenaar_type = 'persoon' → kantoorpersoneel, unieke licentie per persoon
-- eigenaar_type = 'klant'   → klant, 1 device per product
-- mandaat_ulid  → het gedragsmandaat dat bepaalt hoe software zich gedraagt
CREATE TABLE IF NOT EXISTS licenties (
    ulid            TEXT    PRIMARY KEY DEFAULT gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    eigenaar_type   TEXT    NOT NULL CHECK (eigenaar_type IN ('persoon', 'klant')),
    eigenaar_ulid   TEXT    NOT NULL CHECK (is_valid_ulid(eigenaar_ulid)),
    product_ulid    TEXT    NOT NULL REFERENCES software_producten(ulid),
    device_ulid     TEXT    NOT NULL REFERENCES devices(ulid),
    mandaat_ulid    TEXT    NOT NULL REFERENCES mandaten(ulid),  -- gedragsmandaat
    geldig_van      BIGINT  NOT NULL,
    geldig_tot      BIGINT,
    actief          BOOLEAN NOT NULL DEFAULT TRUE,

    -- 1 licentie per eigenaar per product (zowel persoon als klant)
    CONSTRAINT uq_licentie_eigenaar_product UNIQUE (eigenaar_type, eigenaar_ulid, product_ulid)
);

-- Trigger: device eigenaar moet overeenkomen met licentie eigenaar
-- Personeel: device eigenaar_type='kantoor', eigenaar_ulid=persoon.ulid (via mandaat)
-- Klant:     device eigenaar_type='klant', eigenaar_ulid=klant.ulid
CREATE OR REPLACE FUNCTION chk_licentie_device_eigenaar()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.eigenaar_type = 'klant' THEN
        -- Klant: device moet eigendom zijn van die klant
        IF NOT EXISTS (
            SELECT 1 FROM devices
            WHERE ulid = NEW.device_ulid
              AND eigenaar_type = 'klant'
              AND eigenaar_ulid = NEW.eigenaar_ulid
              AND actief = TRUE
        ) THEN
            RAISE EXCEPTION
                'Device % is geen actief device van klant %',
                NEW.device_ulid, NEW.eigenaar_ulid;
        END IF;
    ELSIF NEW.eigenaar_type = 'persoon' THEN
        -- Personeel: device moet eigendom zijn van kantoor
        IF NOT EXISTS (
            SELECT 1 FROM devices
            WHERE ulid = NEW.device_ulid
              AND eigenaar_type = 'kantoor'
              AND actief = TRUE
        ) THEN
            RAISE EXCEPTION
                'Device % is geen actief kantoor device voor persoon %',
                NEW.device_ulid, NEW.eigenaar_ulid;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: mandaat op licentie moet type=gedrag zijn
CREATE OR REPLACE FUNCTION chk_licentie_mandaat_type()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM mandaten
        WHERE ulid = NEW.mandaat_ulid
          AND mandaat_type = 'gedrag'
          AND actief = TRUE
    ) THEN
        RAISE EXCEPTION
            'Licentie % vereist een actief gedragsmandaat, mandaat_ulid: %',
            NEW.ulid, NEW.mandaat_ulid;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_chk_licentie_device ON licenties;
CREATE TRIGGER trg_chk_licentie_device
    BEFORE INSERT OR UPDATE ON licenties
    FOR EACH ROW EXECUTE FUNCTION chk_licentie_device_eigenaar();

DROP TRIGGER IF EXISTS trg_chk_licentie_mandaat ON licenties;
CREATE TRIGGER trg_chk_licentie_mandaat
    BEFORE INSERT OR UPDATE ON licenties
    FOR EACH ROW EXECUTE FUNCTION chk_licentie_mandaat_type();

CREATE TABLE IF NOT EXISTS mandaten (
    ulid            TEXT    PRIMARY KEY DEFAULT gen_ulid()
                            CHECK (is_valid_ulid(ulid)),
    van_persoon_ulid TEXT   NOT NULL REFERENCES personen(ulid),  -- FK via ULID
    naar_type       TEXT    NOT NULL CHECK (naar_type IN ('persoon', 'klant', 'ai_personeel')),
    naar_ulid       TEXT    NOT NULL
                            CHECK (is_valid_ulid(naar_ulid)),
    scope           TEXT    NOT NULL,
    geldig_van      BIGINT  NOT NULL,
    geldig_tot      BIGINT,
    actief          BOOLEAN NOT NULL DEFAULT TRUE,
    meta            JSONB
);

-- Processen: process_ulid IS de primaire sleutel
-- mandaat_ulid is VERPLICHT — altijd lookup via ULID van het mandaat
-- device_ulid — op welke machine draait dit proces
CREATE TABLE IF NOT EXISTS processen (
    process_ulid    TEXT    PRIMARY KEY
                            CHECK (is_valid_ulid(process_ulid)),
    mandaat_ulid    TEXT    NOT NULL
                            REFERENCES mandaten(ulid),           -- VERPLICHTE lookup
    omgeving_ulid   TEXT    NOT NULL
                            REFERENCES omgevingen(ulid),
    device_ulid     TEXT    NOT NULL
                            REFERENCES devices(ulid),            -- op welk device
    agent_type      TEXT    NOT NULL CHECK (agent_type IN ('design', 'implementatie', 'review')),
    start_unix      BIGINT  NOT NULL,
    end_unix        BIGINT,
    tokens_used     BIGINT  NOT NULL DEFAULT 0 CHECK (tokens_used >= 0),
    status          TEXT    NOT NULL DEFAULT 'actief'
                            CHECK (status IN ('actief', 'voltooid', 'mislukt')),
    meta            JSONB,

    CONSTRAINT chk_tijdvolgorde CHECK (end_unix IS NULL OR end_unix >= start_unix)
);

-- Trigger: proces mag niet starten zonder actief mandaat
CREATE OR REPLACE FUNCTION chk_mandaat_actief()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM mandaten
        WHERE ulid = NEW.mandaat_ulid
          AND actief = TRUE
          AND geldig_van <= NEW.start_unix
          AND (geldig_tot IS NULL OR geldig_tot >= NEW.start_unix)
    ) THEN
        RAISE EXCEPTION 'Proces % heeft geen actief mandaat (mandaat_ulid: %)',
            NEW.process_ulid, NEW.mandaat_ulid;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_chk_mandaat_actief ON processen;
CREATE TRIGGER trg_chk_mandaat_actief
    BEFORE INSERT OR UPDATE ON processen
    FOR EACH ROW EXECUTE FUNCTION chk_mandaat_actief();

-- ============================================================
-- Software installaties: technische + gedrag CRUD per device
-- ============================================================

-- Wat er geïnstalleerd staat op een device, met versie en config
CREATE TABLE IF NOT EXISTS software_installaties (
    ulid              TEXT    PRIMARY KEY DEFAULT gen_ulid()
                              CHECK (is_valid_ulid(ulid)),
    device_ulid       TEXT    NOT NULL REFERENCES devices(ulid),
    product_ulid      TEXT    NOT NULL REFERENCES software_producten(ulid),
    licentie_ulid     TEXT    NOT NULL REFERENCES licenties(ulid),
    versie            TEXT    NOT NULL,

    -- Technische config (infrastructuur, poorten, paden, resources)
    technisch_config  JSONB,

    -- Gedrag config (features, limieten, UI gedrag — per licentie/mandaat)
    gedrag_config     JSONB,

    status            TEXT    NOT NULL DEFAULT 'actief'
                              CHECK (status IN ('actief', 'gestopt', 'verwijderd')),
    geinstalleerd_op  BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,
    bijgewerkt_op     BIGINT,
    bijgewerkt_door   TEXT    REFERENCES personen(ulid),

    UNIQUE (device_ulid, product_ulid)
);

-- Audit log: elke CRUD actie op installaties wordt vastgelegd
CREATE TABLE IF NOT EXISTS installatie_log (
    ulid              TEXT    PRIMARY KEY DEFAULT gen_ulid()
                              CHECK (is_valid_ulid(ulid)),
    installatie_ulid  TEXT    NOT NULL REFERENCES software_installaties(ulid),
    actie             TEXT    NOT NULL CHECK (actie IN ('create','update_technisch','update_gedrag','delete')),
    door_persoon_ulid TEXT    NOT NULL REFERENCES personen(ulid),
    oude_waarde       JSONB,
    nieuwe_waarde     JSONB,
    tijdstip          BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT
);

-- Trigger: log elke wijziging op software_installaties automatisch
CREATE OR REPLACE FUNCTION log_installatie_wijziging()
RETURNS TRIGGER AS $$
DECLARE
    v_actie TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_actie := 'create';
        INSERT INTO installatie_log
            (installatie_ulid, actie, door_persoon_ulid, nieuwe_waarde)
        VALUES
            (NEW.ulid, v_actie, COALESCE(NEW.bijgewerkt_door, NEW.licentie_ulid),
             row_to_json(NEW)::JSONB);
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.technisch_config IS DISTINCT FROM NEW.technisch_config THEN
            v_actie := 'update_technisch';
        ELSE
            v_actie := 'update_gedrag';
        END IF;
        INSERT INTO installatie_log
            (installatie_ulid, actie, door_persoon_ulid, oude_waarde, nieuwe_waarde)
        VALUES
            (NEW.ulid, v_actie, COALESCE(NEW.bijgewerkt_door, NEW.licentie_ulid),
             row_to_json(OLD)::JSONB, row_to_json(NEW)::JSONB);
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO installatie_log
            (installatie_ulid, actie, door_persoon_ulid, oude_waarde)
        VALUES
            (OLD.ulid, 'delete', COALESCE(OLD.bijgewerkt_door, OLD.licentie_ulid),
             row_to_json(OLD)::JSONB);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_log_installatie ON software_installaties;
CREATE TRIGGER trg_log_installatie
    AFTER INSERT OR UPDATE OR DELETE ON software_installaties
    FOR EACH ROW EXECUTE FUNCTION log_installatie_wijziging();

-- ============================================================
-- Remote ontkoppeling bij diefstal
-- Alleen Cuiper (god) of Deva (beheerder) mag dit uitvoeren
-- Cascade: alle licenties + actieve processen op het device stoppen
-- ============================================================

CREATE OR REPLACE FUNCTION ontkoppel_device(
    p_device_ulid     TEXT,
    p_door_ulid       TEXT   -- wie voert de ontkoppeling uit
)
RETURNS VOID AS $$
DECLARE
    v_now BIGINT := EXTRACT(EPOCH FROM NOW())::BIGINT;
BEGIN
    -- Cuiper bypast alles — anderen moeten beheerder zijn
    IF NOT is_beheerder(p_door_ulid) THEN
        RAISE EXCEPTION
            'Onvoldoende rechten: alleen Cuiper of Deva mag een device ontkoppelen (actor: %)',
            p_door_ulid;
    END IF;

    -- Device markeren als gestolen + ontkoppeld
    UPDATE devices SET
        gestolen             = TRUE,
        gestolen_gemeld_op   = v_now,
        ontkoppeld_op        = v_now,
        ontkoppeld_door      = p_door_ulid,
        actief               = FALSE
    WHERE ulid = p_device_ulid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Device % niet gevonden', p_device_ulid;
    END IF;

    -- Alle licenties op dit device deactiveren
    UPDATE licenties SET actief = FALSE
    WHERE device_ulid = p_device_ulid;

    -- Alle actieve installaties stoppen
    UPDATE software_installaties SET
        status        = 'gestopt',
        bijgewerkt_op = v_now,
        bijgewerkt_door = p_door_ulid
    WHERE device_ulid = p_device_ulid
      AND status = 'actief';

    -- Alle lopende processen op dit device beëindigen
    UPDATE processen SET
        status    = 'mislukt',
        end_unix  = v_now
    WHERE device_ulid = p_device_ulid
      AND status = 'actief';

    RAISE NOTICE '[ONTKOPPELD] Device % ontkoppeld door % op unix=%',
        p_device_ulid, p_door_ulid, v_now;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- STAP 4: Indexes
-- ============================================================

-- GIN op ULID velden (trigram zoeken)
CREATE INDEX IF NOT EXISTS idx_gin_process_ulid
    ON processen USING GIN (process_ulid gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_gin_mandaat_ulid
    ON mandaten USING GIN (ulid gin_trgm_ops);

-- GIN op JSONB meta
CREATE INDEX IF NOT EXISTS idx_gin_mandaten_meta
    ON mandaten USING GIN (meta);

CREATE INDEX IF NOT EXISTS idx_gin_processen_meta
    ON processen USING GIN (meta);

-- BTree op mandaat_ulid in processen (snelle lookup per proces)
CREATE INDEX IF NOT EXISTS idx_processen_mandaat_ulid
    ON processen (mandaat_ulid);

-- BTree op device_ulid in processen
CREATE INDEX IF NOT EXISTS idx_processen_device_ulid
    ON processen (device_ulid);

-- BTree op licenties eigenaar + product
CREATE INDEX IF NOT EXISTS idx_licenties_eigenaar
    ON licenties (eigenaar_type, eigenaar_ulid);

CREATE INDEX IF NOT EXISTS idx_licenties_device
    ON licenties (device_ulid);

-- BTree op software_installaties
CREATE INDEX IF NOT EXISTS idx_installaties_device
    ON software_installaties (device_ulid);

CREATE INDEX IF NOT EXISTS idx_installaties_status
    ON software_installaties (status);

-- GIN op installatie configs (doorzoekbare JSONB)
CREATE INDEX IF NOT EXISTS idx_gin_installaties_technisch
    ON software_installaties USING GIN (technisch_config);

CREATE INDEX IF NOT EXISTS idx_gin_installaties_gedrag
    ON software_installaties USING GIN (gedrag_config);

-- BTree op installatie_log tijdstip (audit queries)
CREATE INDEX IF NOT EXISTS idx_installatie_log_tijdstip
    ON installatie_log (tijdstip);

CREATE INDEX IF NOT EXISTS idx_installatie_log_installatie
    ON installatie_log (installatie_ulid);

-- BTree op devices: gestolen + GPS
CREATE INDEX IF NOT EXISTS idx_devices_gestolen
    ON devices (gestolen) WHERE gestolen = TRUE;

CREATE INDEX IF NOT EXISTS idx_devices_mac
    ON devices (mac_adres) WHERE mac_adres IS NOT NULL;

-- GIN op devices eigenaar_ulid (snel alle devices per klant/kantoor)
CREATE INDEX IF NOT EXISTS idx_gin_devices_eigenaar
    ON devices USING GIN (eigenaar_ulid gin_trgm_ops);

-- BTree op status + start_unix (actieve processen ophalen)
CREATE INDEX IF NOT EXISTS idx_processen_status_start
    ON processen (status, start_unix);

-- GIN op personen naam/rol
CREATE INDEX IF NOT EXISTS idx_gin_personen
    ON personen USING GIN (naam, rol);

-- IVFFlat vector index (alleen als pgvector geladen)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes WHERE tablename = 'personen'
            AND indexname = 'idx_vec_personen_embedding'
        ) THEN
            EXECUTE 'CREATE INDEX idx_vec_personen_embedding
                     ON personen USING ivfflat (embedding vector_cosine_ops)
                     WITH (lists = 10)';
            RAISE NOTICE '[OK] IVFFlat vector index aangemaakt op personen.embedding';
        END IF;
    END IF;
END;
$$;

-- ============================================================
-- STAP 5: Seed data (alleen als leeg)
-- ============================================================

DO $$
DECLARE
    ulid_cuiper  TEXT := '01HCUIPER000000000000000001';
    ulid_deva    TEXT := '01HDEVA0000000000000000002';
    ulid_code    TEXT := '01HCLAUDECODE0000000000003';
    ulid_web     TEXT := '01HCLAUDEWEB00000000000004';
    ulid_ontwerp TEXT := '01HOMGEVING0ONTWERP000001';
    ulid_test    TEXT := '01HOMGEVING0TEST0000000002';
    ulid_prod_h  TEXT := '01HOMGEVING0PROODHOOFD003';
    ulid_prod_s  TEXT := '01HOMGEVING0PRODSUB000004';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM personen LIMIT 1) THEN
        INSERT INTO personen (ulid, naam, rol, mandaat_niveau) VALUES
            (ulid_cuiper, 'Cuiper',     'Hoofd Architect & Eigenaar', 1),
            (ulid_deva,   'Deva',       'AI Systeembeheerder',        2),
            (ulid_code,   'ClaudeCode', 'AI Personeel CLI',           3),
            (ulid_web,    'Claude.ai',  'AI Personeel Web',           3);
        RAISE NOTICE '[SEED] personen ingevoegd';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM omgevingen LIMIT 1) THEN
        INSERT INTO omgevingen (ulid, naam, niveau, data_klasse, beheer_door) VALUES
            (ulid_ontwerp, 'ontwerp',         1, 'geen_productie', ulid_cuiper),
            (ulid_test,    'test',            2, 'test',           ulid_deva),
            (ulid_prod_h,  'productie_hoofd', 3, 'productie',      ulid_deva),
            (ulid_prod_s,  'productie_sub',   3, 'productie',      ulid_deva);
        RAISE NOTICE '[SEED] omgevingen ingevoegd';
    END IF;
END;
$$;
