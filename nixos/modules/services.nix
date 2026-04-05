{ config, pkgs, ... }:

{
  # ─── PostgreSQL ───────────────────────────────────────────────────────────
  # ÉÉN instantie, GEÏSOLEERDE databases per klant/project
  # Elke klant/project krijgt eigen database + eigen rol
  # Cross-access is onmogelijk door rol-isolatie
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    dataDir = "/data/postgresql";
    enableTCPIP = false;

    authentication = ''
      local all all trust
      host  all all 127.0.0.1/32 trust
    '';

    # Basis setup — klant/project databases via scripts aangemaakt
    initialScript = pkgs.writeText "pg-init.sql" ''
      -- Beheerder
      CREATE USER reparateur WITH SUPERUSER;
      CREATE DATABASE reparateur OWNER reparateur;

      -- Lab gebruiker (geen toegang tot klant databases)
      CREATE USER lab_user WITH PASSWORD 'lab';

      -- Klant gebruiker (geen toegang tot lab databases)
      CREATE USER klant_user WITH PASSWORD 'klant';

      -- Revoke standaard public rechten
      REVOKE ALL ON DATABASE reparateur FROM PUBLIC;
    '';

    settings = {
      # Logging voor audit trail
      log_connections = true;
      log_disconnections = true;
      log_statement = "ddl";
    };
  };

  # ─── Gitea ────────────────────────────────────────────────────────────────
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
    };
  };

  # ─── MQTT — Mosquitto ─────────────────────────────────────────────────────
  # ÉÉN broker, GEÏSOLEERD via topic namespaces
  # klant/jan-bakker/# ← alleen voor jan-bakker
  # lab/project-naam/# ← alleen voor lab projecten
  # test/#             ← air-gap test omgeving
  services.mosquitto = {
    enable = true;
    listeners = [{
      port = 1883;
      address = "127.0.0.1";
      settings.allow_anonymous = false;
      acl = [
        # Beheerder mag alles
        "user reparateur"
        "topic readwrite #"
        ""
        # Klant namespace — geen toegang tot lab of test
        "user klant_mqtt"
        "topic readwrite klant/#"
        ""
        # Lab namespace — geen toegang tot klant of test
        "user lab_mqtt"
        "topic readwrite lab/#"
        ""
        # Air-gap test namespace — volledig geïsoleerd
        "user test_mqtt"
        "topic readwrite test/#"
      ];
    }];
  };

  # ─── Zenoh router ─────────────────────────────────────────────────────────
  # ÉÉN router, GEÏSOLEERD via key-expression namespaces
  # klant/<naam>/** ← klantdata
  # lab/**          ← lab data
  # test/**         ← air-gap test (geen bridge naar buiten)
  environment.systemPackages = with pkgs; [ zenoh ];

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

  # ─── Ollama ───────────────────────────────────────────────────────────────
  # ÉÉN instantie, modellen gedeeld, conversaties gescheiden per script
  services.ollama = {
    enable = true;
    home = "/data/ollama";
  };

  # ─── n8n ──────────────────────────────────────────────────────────────────
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

  # ─── Mappen aanmaken bij boot ─────────────────────────────────────────────
  systemd.tmpfiles.rules = [
    # Gedeelde services data
    "d /data                    0755 reparateur users -"
    "d /data/postgresql         0700 postgres    postgres -"
    "d /data/gitea              0755 gitea       gitea -"
    "d /data/ollama             0755 reparateur  users -"
    "d /data/n8n                0755 reparateur  users -"
    "d /data/logseq             0755 reparateur  users -"
    "d /data/docker             0755 root        root -"

    # Snapshots voor debug/rollback (btrfs)
    "d /data/snapshots          0755 reparateur  users -"
    "d /data/snapshots/klanten  0755 reparateur  users -"
    "d /data/snapshots/lab      0755 reparateur  users -"

    # Klantwerk — geïsoleerd van lab
    "d /projects                0700 reparateur  users -"

    # Lab — geïsoleerd van klanten
    "d /lab                     0700 reparateur  users -"
    "d /lab/projecten           0755 reparateur  users -"
    "d /lab/tests               0755 reparateur  users -"
    "d /lab/docs                0755 reparateur  users -"
    "d /lab/experimenten        0755 reparateur  users -"

    # Air-gap test omgeving — geen toegang tot /projects of /lab
    "d /airgap                  0700 reparateur  users -"
    "d /airgap/tests            0755 reparateur  users -"
    "d /airgap/snapshots        0755 reparateur  users -"
  ];
}
