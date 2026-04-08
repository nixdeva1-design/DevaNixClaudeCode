# ─── CuiperHeader ───────────────────────────────────────────────────────────
# ULID:          01COMP034MINIMAL000000000
# Naam:          nixos/clients/minimal.nix
# Erft via:      CuiperCore → CuiperDonut → nixos/flake.nix
# Aangemaakt:    CuiperStapNr 26
# Gewijzigd:     CuiperStapNr 54 — 2026-04-08
# ────────────────────────────────────────────────────────────────────────────
# CuiperHive Klantprofiel: minimal
# Alleen: PostgreSQL + Gitea + Redis
# Gebruik: nixos-rebuild switch --flake .#minimal
# Typisch voor: kleine klant, budget, of staging omgeving

{ ... }:

{
  cuiper.services = {
    gitea.enable      = true;
    mosquitto.enable  = false;
    ollama.enable     = false;
    n8n.enable        = false;
    zenoh.enable      = false;
    prometheus.enable = false;
    grafana.enable    = false;
    kafka.enable      = false;
    mindsdb.enable    = false;
    mlflow.enable     = false;
  };

  cuiper.databases = {
    postgres.enable = true;
    mongodb.enable  = false;
    redis.enable    = true;
    neo4j.enable    = false;
    duckdb.enable   = false;
    phpfpm.enable   = false;
    ruby.enable     = false;
  };

  cuiper.nginx.enable = true;
}
