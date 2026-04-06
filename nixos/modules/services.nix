{ config, pkgs, ... }:

let
  ports = config.cuiper.ports;
in

{
  # ─── Gitea ────────────────────────────────────────────────────────────────
  services.gitea = {
    enable = true;
    stateDir = "/data/gitea";
    settings = {
      server = {
        DOMAIN   = "localhost";
        HTTP_PORT = ports.gitea;
        ROOT_URL = "http://localhost:${toString ports.gitea}";
      };
      database = {
        DB_TYPE = "postgres";
        HOST    = "127.0.0.1:${toString ports.postgres.primary}";
        NAME    = "gitea";
        USER    = "reparateur";
      };
      service.DISABLE_REGISTRATION = true;
    };
  };

  # ─── MQTT — Mosquitto ─────────────────────────────────────────────────────
  services.mosquitto = {
    enable = true;
    listeners = [{
      port    = ports.mqtt;
      address = "127.0.0.1";
      settings.allow_anonymous = false;
      acl = [
        "user reparateur"
        "topic readwrite #"
        ""
        "user klant_mqtt"
        "topic readwrite klant/#"
        ""
        "user lab_mqtt"
        "topic readwrite lab/#"
        ""
        "user test_mqtt"
        "topic readwrite test/#"
        ""
        "user agi_mqtt"
        "topic readwrite agi/#"
      ];
    }];
  };

  # ─── Ollama ───────────────────────────────────────────────────────────────
  services.ollama = {
    enable = true;
    home   = "/data/ollama";
    port   = ports.ollama;
  };

  # ─── n8n ──────────────────────────────────────────────────────────────────
  systemd.services.n8n = {
    description = "n8n workflow automatisering";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" "postgresql.service" ];
    environment = {
      N8N_USER_FOLDER            = "/data/n8n";
      N8N_PORT                   = toString ports.n8n;
      N8N_PROTOCOL               = "http";
      N8N_HOST                   = "localhost";
      DB_TYPE                    = "postgresdb";
      DB_POSTGRESDB_HOST         = "localhost";
      DB_POSTGRESDB_PORT         = toString ports.postgres.primary;
      DB_POSTGRESDB_DATABASE     = "n8n";
      DB_POSTGRESDB_USER         = "reparateur";
    };
    serviceConfig = {
      ExecStart      = "${pkgs.n8n}/bin/n8n start";
      Restart        = "on-failure";
      User           = "reparateur";
      WorkingDirectory = "/data/n8n";
      StandardOutput = "append:/data/logs/n8n/n8n.log";
      StandardError  = "append:/data/logs/n8n/n8n-error.log";
    };
  };

  # ─── Zenoh router ─────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [ zenoh ];

  systemd.services.zenoh-router = {
    description = "Zenoh router";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" ];
    serviceConfig = {
      ExecStart     = "${pkgs.zenoh}/bin/zenohd --listen tcp/0.0.0.0:${toString ports.zenoh}";
      Restart       = "on-failure";
      User          = "reparateur";
      StandardOutput = "append:/data/logs/zenoh/zenoh.log";
      StandardError  = "append:/data/logs/zenoh/zenoh-error.log";
    };
  };

  # ─── Prometheus ───────────────────────────────────────────────────────────
  services.prometheus = {
    enable = true;
    port   = ports.prometheus;
    dataDir = "/data/prometheus";
  };

  # ─── Grafana ──────────────────────────────────────────────────────────────
  services.grafana = {
    enable = true;
    dataDir = "/data/grafana";
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = ports.grafana;
      };
      database = {
        type = "postgres";
        host = "127.0.0.1:${toString ports.postgres.primary}";
        name = "grafana";
        user = "reparateur";
      };
    };
  };

  # ─── Kafka ────────────────────────────────────────────────────────────────
  services.apache-kafka = {
    enable = true;
    settings = {
      "listeners"                     = "PLAINTEXT://127.0.0.1:${toString ports.kafka.broker}";
      "log.dirs"                      = "/data/kafka";
      "zookeeper.connect"             = "127.0.0.1:${toString ports.kafka.zookeeper}";
      "log4j.rootLogger"              = "INFO, file";
      "log4j.appender.file.File"      = "/data/logs/kafka/kafka.log";
    };
  };

  # ─── MindsDB ──────────────────────────────────────────────────────────────
  systemd.services.mindsdb = {
    description = "MindsDB ML inference laag";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" "postgresql.service" ];
    environment = {
      MINDSDB_STORAGE_DIR = "/data/mindsdb";
      MINDSDB_PORT        = toString ports.mindsdb.http;
    };
    serviceConfig = {
      ExecStart      = "${pkgs.python312}/bin/python3 -m mindsdb";
      Restart        = "on-failure";
      User           = "reparateur";
      StandardOutput = "append:/data/logs/mindsdb/mindsdb.log";
      StandardError  = "append:/data/logs/mindsdb/mindsdb-error.log";
    };
  };

  # ─── MLflow ───────────────────────────────────────────────────────────────
  systemd.services.mlflow = {
    description = "MLflow experiment tracking";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "network.target" "postgresql.service" ];
    environment = {
      MLFLOW_BACKEND_STORE_URI  = "postgresql://reparateur@localhost:${toString ports.postgres.primary}/mlflow";
      MLFLOW_DEFAULT_ARTIFACT_ROOT = "/data/mlflow/artifacts";
    };
    serviceConfig = {
      ExecStart      = "${pkgs.python312Packages.mlflow}/bin/mlflow server --host 127.0.0.1 --port ${toString ports.mlflow}";
      Restart        = "on-failure";
      User           = "reparateur";
      StandardOutput = "append:/data/logs/mlflow/mlflow.log";
      StandardError  = "append:/data/logs/mlflow/mlflow-error.log";
    };
  };

  # ─── Mappen aanmaken bij boot ─────────────────────────────────────────────
  systemd.tmpfiles.rules = [
    "d /data                       0755 reparateur users -"
    "d /data/gitea                 0755 gitea      gitea -"
    "d /data/ollama                0755 reparateur users -"
    "d /data/n8n                   0755 reparateur users -"
    "d /data/logseq                0755 reparateur users -"
    "d /data/docker                0755 root       root -"
    "d /data/prometheus            0755 prometheus prometheus -"
    "d /data/grafana               0755 grafana    grafana -"
    "d /data/kafka                 0755 reparateur users -"
    "d /data/mindsdb               0755 reparateur users -"
    "d /data/mlflow                0755 reparateur users -"
    "d /data/mlflow/artifacts      0755 reparateur users -"
    "d /data/snapshots             0755 reparateur users -"
    "d /data/snapshots/klanten     0755 reparateur users -"
    "d /data/snapshots/lab         0755 reparateur users -"
    "d /data/logs                  0755 reparateur users -"
    "d /data/logs/n8n              0755 reparateur users -"
    "d /data/logs/zenoh            0755 reparateur users -"
    "d /data/logs/mindsdb          0755 reparateur users -"
    "d /data/logs/mlflow           0755 reparateur users -"
    "d /data/logs/kafka            0755 reparateur users -"
    "d /projects                   0700 reparateur users -"
    "d /lab                        0700 reparateur users -"
    "d /lab/projecten              0755 reparateur users -"
    "d /lab/tests                  0755 reparateur users -"
    "d /lab/docs                   0755 reparateur users -"
    "d /lab/experimenten           0755 reparateur users -"
    "d /airgap                     0700 reparateur users -"
    "d /airgap/tests               0755 reparateur users -"
    "d /airgap/snapshots           0755 reparateur users -"
  ];
}
