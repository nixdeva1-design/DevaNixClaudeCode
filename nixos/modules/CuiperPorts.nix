{ lib, ... }:

# ─── CuiperHive Poortregistry ─────────────────────────────────────────────
# Enige bron van waarheid voor alle poorten
# Conflict-vrij ontworpen op basis van bekende community mismatches
# Alle modules importeren hieruit — nooit hardcoded poorten

{
  options.cuiper.ports = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Centrale poortregistry voor CuiperHive";
  };

  config.cuiper.ports = {

    # ─── Webverkeer ───────────────────────────────────────────
    nginx = {
      http  = 80;
      https = 443;
    };

    # ─── Versiebeheer ─────────────────────────────────────────
    # Gitea: NIET 3000 — conflict met Neo4j, Rails, React, Grafana
    gitea = 3001;

    # ─── Monitoring & BI ──────────────────────────────────────
    # Grafana: NIET 3000 — zie boven
    grafana    = 3100;
    prometheus = 9090;
    kafka-ui   = 9093;   # NIET 8080 — conflict met Tomcat/API gateway

    # ─── Workflow & Automatisering ────────────────────────────
    n8n    = 5678;
    airflow = 8088;      # eigen poort, geen conflict

    # ─── AI / ML ──────────────────────────────────────────────
    ollama  = 11434;
    mindsdb = {
      http  = 47334;
      mysql = 47335;     # MindsDB MySQL compatibiliteit
    };
    mlflow  = 5000;
    jupyter = 8888;

    # ─── Messaging bus ────────────────────────────────────────
    zenoh = 7447;
    mqtt  = 1883;
    kafka = {
      broker    = 9092;
      zookeeper = 2181;
    };

    # ─── API ──────────────────────────────────────────────────
    # NIET 8080 — conflict met Tomcat, Kafka UI
    api-gateway = 8090;

    # ─── Relationele databases ────────────────────────────────
    postgres = {
      primary = 5432;
      replica = 5433;    # replica aparte poort
    };

    # ─── Document databases ───────────────────────────────────
    mongodb   = 27017;
    couchdb   = 5984;

    # ─── Graph databases ──────────────────────────────────────
    # Neo4j: NIET 3000 voor browser — conflict overal
    neo4j = {
      http    = 7474;
      bolt    = 7687;
      browser = 7473;    # NIET 3000
    };

    # ─── Cache ────────────────────────────────────────────────
    redis = 6379;

    # ─── Analytische databases ────────────────────────────────
    # DuckDB: embedded, geen poort nodig
    # ClickHouse als alternatief
    clickhouse = {
      http   = 8123;
      native = 9000;     # NIET 9000 voor ClickHouse als Elasticsearch ook draait
    };

    # ─── Web runtimes ─────────────────────────────────────────
    php-fpm  = 9001;     # NIET 9000 — conflict met ClickHouse native
    ruby-dev = 3002;     # NIET 3000 — conflict overal

    # ─── Beheer ───────────────────────────────────────────────
    ssh = 22;
  };
}
