-- CuiperKantoor — Master schema bestand
-- Voert alle modules uit in de juiste volgorde
-- Elke module is zelfstandig vervangbaar
--
-- Uitvoeren: psql -U <user> -d <db> -f sql/99_main.sql
-- Of per module: psql -U <user> -d <db> -f sql/00_extensions.sql

\i sql/00_extensions.sql
\i sql/01_functions_core.sql
\i sql/02_tables_core.sql
\i sql/03_tables_devices.sql
\i sql/04_tables_mandaten.sql
\i sql/05_tables_software.sql
\i sql/06_tables_processen.sql
\i sql/07_tables_installaties.sql
\i sql/08_tables_geo.sql
\i sql/09_functions_ops.sql
\i sql/10_indexes.sql
\i sql/11_seed.sql
