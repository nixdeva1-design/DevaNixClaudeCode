-- =============================================================
-- MODULE 10: Indexes
-- Vervanging: vervang dit bestand voor andere index strategie
-- Afhankelijkheden: alle tabel modules (02-08)
-- =============================================================

-- Kern tabellen
CREATE INDEX IF NOT EXISTS idx_gin_personen
    ON personen USING GIN (naam, rol);

-- GIN op ULID trigram (snel zoeken op gedeeltelijke ULID)
CREATE INDEX IF NOT EXISTS idx_gin_mandaat_ulid
    ON mandaten USING GIN (ulid gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_gin_process_ulid
    ON processen USING GIN (process_ulid gin_trgm_ops);

-- JSONB GIN indexes (doorzoekbaar zonder schema)
CREATE INDEX IF NOT EXISTS idx_gin_mandaten_meta
    ON mandaten USING GIN (meta);

CREATE INDEX IF NOT EXISTS idx_gin_mandaten_gedrag
    ON mandaten USING GIN (gedrag_config);

CREATE INDEX IF NOT EXISTS idx_gin_processen_meta
    ON processen USING GIN (meta);

CREATE INDEX IF NOT EXISTS idx_gin_installaties_technisch
    ON software_installaties USING GIN (technisch_config);

CREATE INDEX IF NOT EXISTS idx_gin_installaties_gedrag
    ON software_installaties USING GIN (gedrag_config);

-- BTree op veelgebruikte FK relaties
CREATE INDEX IF NOT EXISTS idx_processen_mandaat
    ON processen (mandaat_ulid);

CREATE INDEX IF NOT EXISTS idx_processen_device
    ON processen (device_ulid);

CREATE INDEX IF NOT EXISTS idx_processen_status_start
    ON processen (status, start_unix);

CREATE INDEX IF NOT EXISTS idx_licenties_eigenaar
    ON licenties (eigenaar_type, eigenaar_ulid);

CREATE INDEX IF NOT EXISTS idx_licenties_device
    ON licenties (device_ulid);

CREATE INDEX IF NOT EXISTS idx_installaties_device
    ON software_installaties (device_ulid);

CREATE INDEX IF NOT EXISTS idx_installaties_status
    ON software_installaties (status);

CREATE INDEX IF NOT EXISTS idx_installatie_log_installatie
    ON installatie_log (installatie_ulid);

CREATE INDEX IF NOT EXISTS idx_installatie_log_tijdstip
    ON installatie_log (tijdstip DESC);

-- Devices: gestolen + MAC
CREATE INDEX IF NOT EXISTS idx_devices_gestolen
    ON devices (gestolen) WHERE gestolen = TRUE;

CREATE INDEX IF NOT EXISTS idx_devices_mac
    ON devices (mac_adres) WHERE mac_adres IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_gin_devices_eigenaar
    ON devices USING GIN (eigenaar_ulid gin_trgm_ops);

-- Geo systeem
CREATE INDEX IF NOT EXISTS idx_zones_eigenaar
    ON zones (eigenaar_type, eigenaar_ulid);

CREATE INDEX IF NOT EXISTS idx_zone_ringen_zone
    ON zone_ringen (zone_ulid, ring_volgorde);

CREATE INDEX IF NOT EXISTS idx_locatie_log_device_tijd
    ON device_locatie_log (device_ulid, tijdstip DESC);

CREATE INDEX IF NOT EXISTS idx_locatie_log_buiten
    ON device_locatie_log (device_ulid, tijdstip)
    WHERE binnen_toegestane_ring = FALSE;

CREATE INDEX IF NOT EXISTS idx_overtredingen_open
    ON zone_overtredingen (alert_niveau, tijdstip)
    WHERE afgehandeld = FALSE;

CREATE INDEX IF NOT EXISTS idx_overtredingen_device
    ON zone_overtredingen (device_ulid, tijdstip DESC);

-- Vector index (alleen als pgvector geladen)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes
            WHERE tablename = 'personen' AND indexname = 'idx_vec_personen'
        ) THEN
            EXECUTE 'CREATE INDEX idx_vec_personen
                     ON personen USING ivfflat (embedding vector_cosine_ops)
                     WITH (lists = 10)';
            RAISE NOTICE '[OK] IVFFlat vector index aangemaakt op personen.embedding';
        END IF;
    END IF;
END;
$$;
