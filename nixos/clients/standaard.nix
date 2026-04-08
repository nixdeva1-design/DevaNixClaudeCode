# ─── CuiperHeader ───────────────────────────────────────────────────────────
# ULID:          01COMP032STANDAARD000000
# Naam:          nixos/clients/standaard.nix
# Erft via:      CuiperCore → CuiperDonut → nixos/flake.nix
# Aangemaakt:    CuiperStapNr 19
# Gewijzigd:     CuiperStapNr 54 — 2026-04-08
# ────────────────────────────────────────────────────────────────────────────
# CuiperHive Klantprofiel: standaard
# Volledige installatie — alle services en databases actief
# Gebruik: nixos-rebuild switch --flake .#standaard
#
# Om een klantspecifiek profiel te maken:
#   cp nixos/clients/standaard.nix nixos/clients/acme.nix
#   Pas enable = false toe op wat de klant niet nodig heeft
#   Voeg toe aan flake.nix: acme = mkCuiperSystem ./clients/acme.nix;

{ ... }:

{
  # ─── Services ─────────────────────────────────────────────────────────────
  cuiper.services = {
    gitea.enable      = true;
    mosquitto.enable  = true;
    ollama.enable     = true;
    n8n.enable        = true;
    zenoh.enable      = true;
    prometheus.enable = true;
    grafana.enable    = true;
    kafka.enable      = true;
    mindsdb.enable    = true;
    mlflow.enable     = true;
  };

  # ─── Databases ────────────────────────────────────────────────────────────
  cuiper.databases = {
    postgres.enable = true;
    mongodb.enable  = true;
    redis.enable    = true;
    neo4j.enable    = true;
    duckdb.enable   = true;
    phpfpm.enable   = false;
    ruby.enable     = false;
  };

  # ─── Tracing ──────────────────────────────────────────────────────────
  cuiper.jaeger.enable = true;

  # ─── Nginx — proxy voor alle actieve services ──────────────────────────
  cuiper.nginx.enable = true;
}
