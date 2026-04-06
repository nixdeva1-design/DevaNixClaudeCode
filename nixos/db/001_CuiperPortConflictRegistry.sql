-- CuiperHive Kennisdatabase: poort- en component conflicten
-- Sedimentatie van bekende mismatches uit de developer community
-- Data wordt geammendeerd, nooit verwijderd
-- Aangemaakt: 2026-04-05

-- ─── Tabellen ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS port_registry (
  poort        INTEGER PRIMARY KEY,
  service      TEXT    NOT NULL,
  protocol     TEXT    DEFAULT 'tcp',
  in_stack     BOOLEAN DEFAULT false,
  cuiper_poort INTEGER,              -- onze toegewezen poort als afwijkend
  notitie      TEXT,
  aangemaakt   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS port_conflicts (
  id          SERIAL PRIMARY KEY,
  poort       INTEGER REFERENCES port_registry(poort),
  service_a   TEXT NOT NULL,
  service_b   TEXT NOT NULL,
  beschrijving TEXT,
  oplossing    TEXT,
  bron         TEXT,
  aangemaakt   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS component_conflicts (
  id          SERIAL PRIMARY KEY,
  component_a TEXT NOT NULL,
  component_b TEXT NOT NULL,
  type        TEXT NOT NULL,  -- poort | namespace | library | bestand | os
  beschrijving TEXT,
  oplossing    TEXT,
  ernst        TEXT DEFAULT 'medium',  -- low | medium | high | kritiek
  bron         TEXT,
  aangemaakt   TIMESTAMPTZ DEFAULT NOW()
);

-- Amendement log — niets verdwijnt
CREATE TABLE IF NOT EXISTS conflict_amendement (
  id              SERIAL PRIMARY KEY,
  tabel           TEXT NOT NULL,
  record_id       INTEGER,
  wijziging       JSONB,
  reden           TEXT,
  cuiper_stap_nr  INTEGER,
  aangemaakt      TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Bekende poorten ──────────────────────────────────────────────────────

INSERT INTO port_registry (poort, service, in_stack, cuiper_poort, notitie) VALUES
  (80,    'HTTP/Nginx',         true,  80,    'standaard'),
  (443,   'HTTPS/Nginx',        true,  443,   'standaard'),
  (22,    'SSH',                true,  22,    'standaard'),
  (3000,  'Grafana/Gitea/Neo4j/Rails/React', false, null, 'KRITIEK conflict — niet gebruiken'),
  (3001,  'Gitea (CuiperHive)', true,  3001,  'verplaatst van 3000'),
  (3100,  'Grafana (CuiperHive)',true, 3100,  'verplaatst van 3000'),
  (3306,  'MySQL',              false, null,  'niet in stack maar gereserveerd'),
  (5000,  'MLflow',             true,  5000,  'standaard MLflow'),
  (5432,  'PostgreSQL primary', true,  5432,  'standaard'),
  (5433,  'PostgreSQL replica', true,  5433,  'replica aparte poort'),
  (5678,  'n8n',                true,  5678,  'standaard'),
  (5984,  'CouchDB',            false, null,  'niet in stack'),
  (6379,  'Redis',              true,  6379,  'standaard'),
  (7473,  'Neo4j Browser',      true,  7473,  'verplaatst van 3000'),
  (7474,  'Neo4j HTTP',         true,  7474,  'standaard'),
  (7447,  'Zenoh',              true,  7447,  'standaard'),
  (7687,  'Neo4j Bolt',         true,  7687,  'standaard'),
  (8080,  'Tomcat/generiek',    false, null,  'VERMIJDEN — te generiek'),
  (8088,  'Airflow',            false, null,  'niet in stack'),
  (8090,  'API Gateway CuiperHive', true, 8090, 'verplaatst van 8080'),
  (8123,  'ClickHouse HTTP',    false, null,  'niet in stack, gereserveerd'),
  (8888,  'Jupyter',            true,  8888,  'standaard'),
  (9000,  'ClickHouse native/SonarQube', false, null, 'VERMIJDEN — conflict'),
  (9001,  'PHP-FPM',            true,  9001,  'NIET 9000 — conflict ClickHouse'),
  (9090,  'Prometheus',         true,  9090,  'standaard'),
  (9092,  'Kafka broker',       true,  9092,  'standaard'),
  (9093,  'Kafka UI CuiperHive',true,  9093,  'verplaatst van 8080'),
  (9200,  'Elasticsearch HTTP', false, null,  'niet in stack, gereserveerd'),
  (9300,  'Elasticsearch cluster', false, null, 'niet in stack'),
  (11434, 'Ollama',             true,  11434, 'standaard'),
  (1883,  'MQTT',               true,  1883,  'standaard'),
  (2181,  'Kafka Zookeeper',    true,  2181,  'standaard'),
  (27017, 'MongoDB',            true,  27017, 'standaard'),
  (47334, 'MindsDB HTTP',       true,  47334, 'standaard'),
  (47335, 'MindsDB MySQL compat',true, 47335, 'standaard')
ON CONFLICT (poort) DO NOTHING;

-- ─── Bekende poort conflicten ─────────────────────────────────────────────

INSERT INTO port_conflicts (poort, service_a, service_b, beschrijving, oplossing, bron) VALUES
  (3000, 'Grafana', 'Gitea',
   'Beide gebruiken 3000 als standaard',
   'Gitea → 3001, Grafana → 3100, Neo4j Browser → 7473',
   'community bekend'),

  (3000, 'Neo4j Browser', 'Rails development',
   'Neo4j browser en Rails dev server botsen op 3000',
   'Neo4j Browser → 7473, Rails → 3002',
   'community bekend'),

  (3000, 'React dev server', 'Grafana',
   'React dev en Grafana botsen op 3000',
   'React → 3002+, Grafana → 3100',
   'community bekend'),

  (8080, 'Tomcat', 'Kafka UI',
   'Generieke poort, teveel services gebruiken 8080',
   'Gebruik specifieke poorten per service',
   'community bekend'),

  (9000, 'ClickHouse native', 'SonarQube',
   'Zowel ClickHouse als SonarQube gebruiken 9000',
   'PHP-FPM → 9001, ClickHouse native vermijden of 9900',
   'community bekend'),

  (5000, 'MLflow', 'Flask/Werkzeug dev',
   'Flask dev server gebruikt ook 5000 op macOS/Linux',
   'MLflow op 5000, Flask dev → 5001 of andere poort',
   'community bekend');

-- ─── Component conflicten ─────────────────────────────────────────────────

INSERT INTO component_conflicts
  (component_a, component_b, type, beschrijving, oplossing, ernst, bron) VALUES

  ('PostgreSQL pgvector', 'PostgreSQL standaard',
   'library',
   'pgvector extensie moet apart geïnstalleerd worden als Nix package',
   'postgresql16Packages.pgvector als extraPlugin',
   'medium', 'NixOS wiki'),

  ('Neo4j', 'Java heap',
   'os',
   'Neo4j vereist JVM, zwaar op geheugen, conflicteert met andere JVM services',
   'Neo4j heap beperken via NEO4J_dbms_memory_heap_max__size',
   'high', 'Neo4j docs'),

  ('MongoDB', 'btrfs',
   'bestand',
   'MongoDB heeft problemen met btrfs journaling — moet op XFS of ext4 subvolume',
   'MongoDB data op apart ext4 geformateerd bestand of loop device',
   'high', 'MongoDB docs'),

  ('Kafka', 'Zookeeper',
   'poort',
   'Kafka vereist Zookeeper op 2181, KRaft modus vervangt dit in Kafka 3.x',
   'Gebruik Kafka 3.x met KRaft modus — geen Zookeeper nodig',
   'medium', 'Kafka docs 3.x'),

  ('MindsDB', 'MySQL client',
   'poort',
   'MindsDB MySQL compatibiliteitspoort 47335 kan conflicteren met MySQL tools',
   'MySQL zelf niet installeren als MindsDB MySQL compat actief is',
   'low', 'MindsDB docs'),

  ('PHP-FPM', 'Nginx',
   'bestand',
   'PHP-FPM socket vs TCP — socket sneller maar pad moet overeenkomen in Nginx config',
   'Gebruik TCP poort 9001 voor consistentie, socket voor productie',
   'low', 'community bekend'),

  ('DuckDB', 'Python multiprocessing',
   'library',
   'DuckDB embedded kan niet tegelijk door meerdere processen geopend worden',
   'Gebruik DuckDB server mode of serialiseer toegang via queue',
   'medium', 'DuckDB docs'),

  ('Redis', 'btrfs compressie',
   'os',
   'Redis AOF logging presteert slecht met btrfs compressie aan',
   'Redis data op subvolume zonder compressie: noatime,nodatacow',
   'medium', 'Redis docs'),

  ('Ollama', 'GPU VRAM',
   'os',
   'Ollama zonder GPU valt terug op CPU — grote modellen traag op USB systeem',
   'Gebruik modellen max 7B op CPU, kleinere voor snelheid',
   'medium', 'Ollama docs'),

  ('n8n', 'PostgreSQL',
   'library',
   'n8n heeft specifieke PostgreSQL versie nodig voor JSON operaties',
   'PostgreSQL 14+ vereist, wij gebruiken 16 — geen probleem',
   'low', 'n8n docs'),

  ('Ruby gems', 'NixOS',
   'os',
   'Ruby gems met native extensions werken niet zomaar op NixOS',
   'Gebruik bundix of nix-shell met buildInputs voor native deps',
   'high', 'NixOS wiki Ruby'),

  ('PHP composer', 'NixOS',
   'os',
   'Composer packages met native extensions vereisen NixOS wrapping',
   'Gebruik phpPackages in Nix of nix-shell per project',
   'medium', 'NixOS wiki PHP');
