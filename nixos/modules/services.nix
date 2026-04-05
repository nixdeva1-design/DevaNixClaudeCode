{ config, pkgs, ... }:

{
  # ─── PostgreSQL ───────────────────────────────────────────────────────────
  # Data staat in /data/postgresql
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    dataDir = "/data/postgresql";
    enableTCPIP = false;  # alleen lokaal
    authentication = ''
      local all all trust
      host  all all 127.0.0.1/32 trust
    '';
    initialScript = pkgs.writeText "pg-init.sql" ''
      CREATE USER reparateur WITH SUPERUSER;
      CREATE DATABASE reparateur OWNER reparateur;
    '';
  };

  # ─── Gitea (zelf-gehoste git) ─────────────────────────────────────────────
  services.gitea = {
    enable = true;
    stateDir = "/data/gitea";
    settings = {
      server = {
        DOMAIN = "localhost";
        HTTP_PORT = 3000;
        ROOT_URL = "http://localhost:3000";
      };
      database = {
        DB_TYPE = "postgres";
        HOST = "127.0.0.1:5432";
        NAME = "gitea";
        USER = "reparateur";
      };
      service.DISABLE_REGISTRATION = true;
      ui.DEFAULT_THEME = "arc-green";
    };
  };

  # ─── MQTT (Mosquitto) ─────────────────────────────────────────────────────
  services.mosquitto = {
    enable = true;
    listeners = [{
      port = 1883;
      address = "127.0.0.1";
      settings.allow_anonymous = true;
    }];
  };

  # ─── Ollama (lokale AI, geen internet nodig) ──────────────────────────────
  services.ollama = {
    enable = true;
    home = "/data/ollama";
    # GPU acceleratie als beschikbaar
    acceleration = null;  # zet op "cuda" of "rocm" bij GPU
  };

  # ─── n8n (workflow automatisering) ───────────────────────────────────────
  # n8n draait via systemd, data in /data/n8n
  systemd.services.n8n = {
    description = "n8n workflow automatisering";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "postgresql.service" ];
    environment = {
      N8N_USER_FOLDER = "/data/n8n";
      N8N_PORT = "5678";
      N8N_PROTOCOL = "http";
      N8N_HOST = "localhost";
      DB_TYPE = "postgresdb";
      DB_POSTGRESDB_HOST = "localhost";
      DB_POSTGRESDB_PORT = "5432";
      DB_POSTGRESDB_DATABASE = "n8n";
      DB_POSTGRESDB_USER = "reparateur";
    };
    serviceConfig = {
      ExecStart = "${pkgs.n8n}/bin/n8n start";
      Restart = "on-failure";
      User = "reparateur";
      WorkingDirectory = "/data/n8n";
    };
  };

  # ─── Zenoh router ─────────────────────────────────────────────────────────
  # Zenoh is een moderne messaging bus (vervanger voor DDS/MQTT voor IoT)
  environment.systemPackages = with pkgs; [
    zenoh  # zenohd router + tools
  ];

  systemd.services.zenoh-router = {
    description = "Zenoh router";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.zenoh}/bin/zenohd";
      Restart = "on-failure";
      User = "reparateur";
    };
  };

  # ─── Data mappen aanmaken bij boot ───────────────────────────────────────
  systemd.tmpfiles.rules = [
    # Systeem data
    "d /data                    0755 reparateur users -"
    "d /data/postgresql         0700 postgres    postgres -"
    "d /data/gitea              0755 gitea       gitea -"
    "d /data/ollama             0755 reparateur  users -"
    "d /data/n8n                0755 reparateur  users -"
    "d /data/logseq             0755 reparateur  users -"
    "d /data/docker             0755 root        root -"

    # Klantprojecten — gescheiden van lab
    "d /projects                0755 reparateur  users -"

    # Persoonlijk lab — gescheiden van klanten
    "d /lab                     0755 reparateur  users -"
    "d /lab/projecten           0755 reparateur  users -"
    "d /lab/tests               0755 reparateur  users -"
    "d /lab/docs                0755 reparateur  users -"
    "d /lab/experimenten        0755 reparateur  users -"
  ];
}
