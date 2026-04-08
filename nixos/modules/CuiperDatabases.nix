# ─── CuiperHeader ───────────────────────────────────────────────────────────
# ULID:          01COMP009DATABASES000000
# Naam:          nixos/modules/CuiperDatabases.nix
# Erft via:      CuiperCore → CuiperDonut
# Aangemaakt:    CuiperStapNr 33
# Gewijzigd:     CuiperStapNr 54 — 2026-04-08
# ────────────────────────────────────────────────────────────────────────────
{ config, lib, pkgs, ... }:

let
  cfg   = config.cuiper.databases;
  ports = config.cuiper.ports;
in

{
  # ─── Module opties — elke database is opt-in ──────────────────────────────
  options.cuiper.databases = {
    postgres.enable = lib.mkEnableOption "PostgreSQL + pgvector";
    mongodb.enable  = lib.mkEnableOption "MongoDB document database";
    redis.enable    = lib.mkEnableOption "Redis cache";
    neo4j.enable    = lib.mkEnableOption "Neo4j graph database";
    duckdb.enable   = lib.mkEnableOption "DuckDB analytische CLI";
    phpfpm.enable   = lib.mkEnableOption "PHP-FPM runtime";
    ruby.enable     = lib.mkEnableOption "Ruby runtime";
  };

  config = lib.mkMerge [

    # ─── PostgreSQL + pgvector ───────────────────────────────────────────────
    (lib.mkIf cfg.postgres.enable {
      services.postgresql = {
        enable      = true;
        package     = pkgs.postgresql_16;
        dataDir     = "/data/postgresql";
        port        = ports.postgres.primary;
        enableTCPIP = false;

        authentication = ''
          local all all trust
          host  all all 127.0.0.1/32 trust
        '';

        initialScript = pkgs.writeText "pg-init.sql" ''
          CREATE USER reparateur WITH SUPERUSER;

          -- Basis database
          CREATE DATABASE reparateur OWNER reparateur;

          -- Service databases — elke service isoleert zijn data
          CREATE DATABASE gitea   OWNER reparateur;
          CREATE DATABASE n8n     OWNER reparateur;
          CREATE DATABASE grafana OWNER reparateur;
          CREATE DATABASE mlflow  OWNER reparateur;

          -- Geïsoleerde rollen per namespace
          CREATE USER lab_user   WITH PASSWORD 'lab';
          CREATE USER klant_user WITH PASSWORD 'klant';

          -- Toegangsbeperking
          REVOKE ALL ON DATABASE reparateur FROM PUBLIC;
          REVOKE ALL ON DATABASE gitea      FROM PUBLIC;
          REVOKE ALL ON DATABASE n8n        FROM PUBLIC;
          REVOKE ALL ON DATABASE grafana    FROM PUBLIC;
          REVOKE ALL ON DATABASE mlflow     FROM PUBLIC;

          -- pgvector extensie activeren op reparateur database
          \c reparateur
          CREATE EXTENSION IF NOT EXISTS vector;
          CREATE EXTENSION IF NOT EXISTS pg_trgm;
        '';

        extraPlugins = with pkgs.postgresql16Packages; [ pgvector ];

        settings = {
          log_connections      = true;
          log_disconnections   = true;
          log_statement        = "ddl";
          work_mem             = "64MB";
          maintenance_work_mem = "256MB";
        };
      };
    })

    # ─── MongoDB ────────────────────────────────────────────────────────────
    (lib.mkIf cfg.mongodb.enable {
      services.mongodb = {
        enable  = true;
        dbpath  = "/data/mongodb";
        bind_ip = "127.0.0.1";
        port    = ports.mongodb;
      };
      systemd.tmpfiles.rules = [ "d /data/mongodb 0755 mongodb mongodb -" ];
    })

    # ─── Redis ──────────────────────────────────────────────────────────────
    (lib.mkIf cfg.redis.enable {
      services.redis.servers.main = {
        enable  = true;
        bind    = "127.0.0.1";
        port    = ports.redis;
        save    = [ [3600 1] [300 100] [60 10000] ];
        logfile = "/data/logs/redis/redis.log";
      };
      systemd.tmpfiles.rules = [ "d /data/logs/redis 0755 redis redis -" ];
    })

    # ─── Neo4j ──────────────────────────────────────────────────────────────
    (lib.mkIf cfg.neo4j.enable {
      services.neo4j = {
        enable           = true;
        directories.home = "/data/neo4j";
        bolt = {
          enable        = true;
          listenAddress = "127.0.0.1:${toString ports.neo4j.bolt}";
        };
        http = {
          enable        = true;
          listenAddress = "127.0.0.1:${toString ports.neo4j.http}";
        };
      };
      systemd.tmpfiles.rules = [ "d /data/neo4j 0755 neo4j neo4j -" ];
    })

    # ─── DuckDB — embedded, alleen CLI ──────────────────────────────────────
    (lib.mkIf cfg.duckdb.enable {
      environment.systemPackages = [ pkgs.duckdb ];
    })

    # ─── PHP-FPM ────────────────────────────────────────────────────────────
    (lib.mkIf cfg.phpfpm.enable {
      services.phpfpm.pools.main = {
        user       = "reparateur";
        group      = "users";
        phpPackage = pkgs.php83;
        settings = {
          "listen"                     = "127.0.0.1:${toString ports.php-fpm}";
          "pm"                         = "dynamic";
          "pm.max_children"            = 10;
          "pm.start_servers"           = 2;
          "pm.min_spare_servers"       = 1;
          "pm.max_spare_servers"       = 5;
          "catch_workers_output"       = true;
          "php_admin_value[error_log]" = "/data/logs/php/error.log";
        };
      };
      systemd.tmpfiles.rules = [ "d /data/logs/php 0755 reparateur users -" ];
    })

    # ─── Ruby ───────────────────────────────────────────────────────────────
    (lib.mkIf cfg.ruby.enable {
      environment.systemPackages = with pkgs; [ ruby_3_3 bundler ];
    })

    # ─── Log mappen (altijd aanwezig) ───────────────────────────────────────
    {
      systemd.tmpfiles.rules = [
        "d /data/logs/nginx 0755 nginx nginx -"
      ];
    }
  ];
}
