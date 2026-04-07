-- =============================================================
-- MODULE 11: Seed data
-- Vervanging: vervang dit bestand voor andere initiële data
-- Afhankelijkheden: alle tabel modules (02-08)
-- Alle ULIDs: 26 tekens, Crockford Base32 (geen I L O U)
-- Schema: 0-9 A-H J K M N P Q R S T V W X Y Z
-- =============================================================

DO $$
DECLARE
    -- Personen (mandaat_niveau 1-3)
    u_cuiper  TEXT := '01HC0000000000000000000001';  -- Cuiper  niveau=1
    u_deva    TEXT := '01HD0000000000000000000002';  -- Deva    niveau=2
    u_code    TEXT := '01HC0000000000000000000003';  -- ClaudeCode niveau=3
    u_web     TEXT := '01HC0000000000000000000004';  -- Claude.ai  niveau=3

    -- Omgevingen
    u_ontwerp TEXT := '01HE0000000000000000000001';  -- ontwerp
    u_test    TEXT := '01HE0000000000000000000002';  -- test
    u_prod_h  TEXT := '01HE0000000000000000000003';  -- productie_hoofd
    u_prod_s  TEXT := '01HE0000000000000000000004';  -- productie_sub
BEGIN

    -- Personen (alleen als leeg)
    IF NOT EXISTS (SELECT 1 FROM personen LIMIT 1) THEN
        INSERT INTO personen (ulid, naam, rol, mandaat_niveau) VALUES
            (u_cuiper, 'Cuiper',     'Hoofd Architect & Eigenaar', 1),
            (u_deva,   'Deva',       'AI Systeembeheerder',        2),
            (u_code,   'ClaudeCode', 'AI Personeel CLI',           3),
            (u_web,    'Claude.ai',  'AI Personeel Web',           3);
        RAISE NOTICE '[SEED] % personen ingevoegd', 4;
    ELSE
        RAISE NOTICE '[SEED] personen al aanwezig — overgeslagen';
    END IF;

    -- Omgevingen (alleen als leeg)
    IF NOT EXISTS (SELECT 1 FROM omgevingen LIMIT 1) THEN
        INSERT INTO omgevingen (ulid, naam, niveau, data_klasse, beheer_door) VALUES
            (u_ontwerp, 'ontwerp',         1, 'geen_productie', u_cuiper),
            (u_test,    'test',            2, 'test',           u_deva),
            (u_prod_h,  'productie_hoofd', 3, 'productie',      u_deva),
            (u_prod_s,  'productie_sub',   3, 'productie',      u_deva);
        RAISE NOTICE '[SEED] % omgevingen ingevoegd', 4;
    ELSE
        RAISE NOTICE '[SEED] omgevingen al aanwezig — overgeslagen';
    END IF;

END;
$$;
