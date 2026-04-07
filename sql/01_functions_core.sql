-- =============================================================
-- MODULE 01: Core functies
-- Vervanging: vervang dit bestand voor andere ULID/rechten implementatie
-- Afhankelijkheden: 00_extensions.sql
-- Fixes t.o.v. origineel:
--   - gen_ulid() hernoemd naar ck_gen_ulid() — voorkomt recursie met pg_ulid
--   - is_cuiper() en is_beheerder() vereisen personen tabel (geladen in 02)
--   - gps_afstand_m() hier geplaatst (pure functie, geen tabel deps)
-- =============================================================

-- ULID validatie: Crockford Base32, exact 26 tekens
-- Uitsloten: I L O U (visuele verwarring)
CREATE OR REPLACE FUNCTION is_valid_ulid(val TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN val ~ '^[0123456789ABCDEFGHJKMNPQRSTVWXYZ]{26}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ULID generatie: gebruikt pg_ulid native functie indien geladen,
-- anders tijdstempel + random suffix in Crockford Base32 subset
-- Hernoemd naar ck_gen_ulid() om recursie met pg_ulid te voorkomen
CREATE OR REPLACE FUNCTION ck_gen_ulid()
RETURNS TEXT AS $$
DECLARE
    v_ts   TEXT;
    v_rand TEXT;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_ulid') THEN
        -- pg_ulid levert zijn eigen gen_ulid() — aanroepen via schema
        RETURN extensions.gen_ulid();
    END IF;
    -- Fallback: 10-char tijdstempel + 16-char random (Base32 subset)
    v_ts   := lpad(to_hex(
                  (EXTRACT(EPOCH FROM clock_timestamp()) * 1000)::BIGINT
              ), 10, '0');
    v_rand := upper(substring(
                  replace(replace(replace(
                      encode(gen_random_bytes(12), 'base64'),
                  '+','X'), '/','Y'), '=','0')
              FROM 1 FOR 16));
    RETURN upper(v_ts) || v_rand;
END;
$$ LANGUAGE plpgsql;

-- God rechten: TRUE als actor mandaat_niveau = 1 (Cuiper)
-- Alle beveiligde triggers controleren dit eerst
CREATE OR REPLACE FUNCTION is_cuiper(actor_ulid TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM personen
        WHERE ulid = actor_ulid
          AND mandaat_niveau = 1
          AND actief = TRUE
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Beheerder rechten: TRUE als actor niveau <= 2 (Cuiper of Deva)
CREATE OR REPLACE FUNCTION is_beheerder(actor_ulid TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM personen
        WHERE ulid = actor_ulid
          AND mandaat_niveau <= 2
          AND actief = TRUE
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- Haversine formule: afstand in meters tussen twee GPS coordinaten
-- Pure functie — geen tabel afhankelijkheden
CREATE OR REPLACE FUNCTION gps_afstand_m(
    lat1 NUMERIC, lon1 NUMERIC,
    lat2 NUMERIC, lon2 NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
    r       NUMERIC := 6371000;
    phi1    NUMERIC := radians(lat1);
    phi2    NUMERIC := radians(lat2);
    dphi    NUMERIC := radians(lat2 - lat1);
    dlambda NUMERIC := radians(lon2 - lon1);
    a       NUMERIC;
BEGIN
    a := sin(dphi / 2) ^ 2
       + cos(phi1) * cos(phi2) * sin(dlambda / 2) ^ 2;
    RETURN r * 2 * atan2(sqrt(a), sqrt(1 - a));
END;
$$ LANGUAGE plpgsql IMMUTABLE;
