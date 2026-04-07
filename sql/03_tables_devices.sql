-- =============================================================
-- MODULE 03: Devices tabel
-- Vervanging: vervang dit bestand voor andere device tracking implementatie
-- Afhankelijkheden: 02_tables_core.sql (personen FK)
-- =============================================================

-- Elke fysieke of virtuele machine (laptop, server, cloud VM)
-- eigenaar_type = 'kantoor' → kantoor device (personeel gebruik)
-- eigenaar_type = 'klant'   → klant eigendom
CREATE TABLE IF NOT EXISTS devices (
    ulid              TEXT    PRIMARY KEY DEFAULT ck_gen_ulid()
                              CHECK (is_valid_ulid(ulid)),
    naam              TEXT    NOT NULL,
    type              TEXT    NOT NULL CHECK (type IN ('laptop', 'server', 'cloud_vm')),
    eigenaar_type     TEXT    NOT NULL CHECK (eigenaar_type IN ('kantoor', 'klant')),
    eigenaar_ulid     TEXT    NOT NULL CHECK (is_valid_ulid(eigenaar_ulid)),

    -- Hardware identiteit
    mac_adres         TEXT    UNIQUE,  -- primaire hardware identifier

    -- Vaste standplaats (thuislocatie)
    standplaats       TEXT,
    standplaats_lat   NUMERIC(10, 7),
    standplaats_lon   NUMERIC(10, 7),

    -- Live GPS positie (bijgewerkt via polling)
    gps_lat           NUMERIC(10, 7),
    gps_lon           NUMERIC(10, 7),
    gps_bijgewerkt_op BIGINT,

    -- Eigen cloud: klant draait product in eigen cloud omgeving
    eigen_cloud       BOOLEAN NOT NULL DEFAULT FALSE,
    cloud_provider    TEXT    CHECK (
                          cloud_provider IN ('azure', 'aws', 'gcp', 'overig')
                      ),

    -- Status
    actief            BOOLEAN NOT NULL DEFAULT TRUE,
    aangemaakt_op     BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT,

    -- Diefstal tracking
    gestolen          BOOLEAN NOT NULL DEFAULT FALSE,
    gestolen_gemeld_op BIGINT,
    ontkoppeld_op     BIGINT,
    ontkoppeld_door   TEXT    REFERENCES personen(ulid),

    CONSTRAINT chk_cloud_provider CHECK (
        (eigen_cloud = FALSE AND cloud_provider IS NULL) OR
        (eigen_cloud = TRUE  AND cloud_provider IS NOT NULL)
    ),
    CONSTRAINT chk_gestolen_tijdstip CHECK (
        (gestolen = FALSE) OR
        (gestolen = TRUE AND gestolen_gemeld_op IS NOT NULL)
    )
);
