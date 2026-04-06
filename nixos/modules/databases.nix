{ config, pkgs, ... }:

let
  ports = config.cuiper.ports;
in

{
  # ─── PostgreSQL ───────────────────────────────────────────────────────────
  services.postgresql = {
    enable  = true;
    package = pkgs.postgresql_16;
    dataDir = "/data/postgresql";
    port    = ports.postgres.primary;
    enableTCPIP = false;

    authentication = ''
      local all all trust
      host  all all 127.0.0.1/32 trust
    '';

    initialScript = pkgs.writeText "pg-init.sql" ''
      CREATE USER reparateur WITH SUPERUSER;
      CREATE DATABASE reparateur OWNER reparateur;
      CREATE USER lab_user  WITH PASSWORD 'lab';
      CREATE USER klant_user WITH PASSWORD 'klant';
      REVOKE ALL ON DATABASE reparateur FROM PUBLIC;
    '';

    # pgvector extensie voor vector search
    extraPlugins = with pkgs.postgresql16Packages; [ pgvector ];

    settings = {
      log_connections    = true;
      log_disconnections = true;
      log_statement      = "ddl";
      # GIN index performance
      work_mem           = "64MB";
      maintenance_work_mem = "256MB";
    };
  };

  # ─── MongoDB ──────────────────────────────────────────────────────────────
  services.mongodb = {
    enable   = true;
    dbpath   = "/data/mongodb";
    bind_ip  = "127.0.0.1";
    port     = ports.mongodb;
  };

  # ─── Redis ────────────────────────────────────────────────────────────────
  services.redis.servers.main = {
    enable  = true;
    bind    = "127.0.0.1";
    port    = ports.redis;
    save    = [ [3600 1] [300 100] [60 10000] ];
    logfile = "/data/logs/redis/redis.log";
  };

  # ─── Neo4j ────────────────────────────────────────────────────────────────
  services.neo4j = {
    enable      = true;
    directories.home = "/data/neo4j";
    bolt = {
      enable = true;
      listenAddress = "127.0.0.1:${toString ports.neo4j.bolt}";
    };
    http = {
      enable = true;
      listenAddress = "127.0.0.1:${toString ports.neo4j.http}";
    };
  };

  # ─── DuckDB ───────────────────────────────────────────────────────────────
  # DuckDB is embedded — geen server, geen poort
  # Beschikbaar als CLI tool en Python/Rust library
  environment.systemPackages = with pkgs; [
    duckdb
  ];

  # ─── PHP ──────────────────────────────────────────────────────────────────
  services.phpfpm.pools.main = {
    user  = "reparateur";
    group = "users";
    phpPackage = pkgs.php83;
    settings = {
      "listen"                  = "127.0.0.1:${toString ports.php-fpm}";
      "pm"                      = "dynamic";
      "pm.max_children"         = 10;
      "pm.start_servers"        = 2;
      "pm.min_spare_servers"    = 1;
      "pm.max_spare_servers"    = 5;
      "catch_workers_output"    = true;
      "php_admin_value[error_log]" = "/data/logs/php/error.log";
    };
  };

  # ─── Ruby ─────────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    ruby_3_3
    bundler
  ];

  # ─── Log mappen ───────────────────────────────────────────────────────────
  systemd.tmpfiles.rules = [
    "d /data/mongodb         0755 mongodb    mongodb -"
    "d /data/neo4j           0755 neo4j      neo4j -"
    "d /data/logs/redis      0755 redis      redis -"
    "d /data/logs/php        0755 reparateur users -"
    "d /data/logs/nginx      0755 nginx      nginx -"
  ];
}
