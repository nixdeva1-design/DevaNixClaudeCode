{ config, lib, pkgs, ... }:

let
  cfg   = config.cuiper.services;
  ports = config.cuiper.ports;
in

{
  # ─── Module opties — elke service is opt-in ───────────────────────────────
  options.cuiper.services = {
    gitea.enable     = lib.mkEnableOption "Gitea git server";
    mosquitto.enable = lib.mkEnableOption "Mosquitto MQTT broker";
    ollama.enable    = lib.mkEnableOption "Ollama LLM inference";
    n8n.enable       = lib.mkEnableOption "n8n workflow automatisering";
    zenoh.enable     = lib.mkEnableOption "Zenoh message bus router";
    prometheus.enable = lib.mkEnableOption "Prometheus monitoring";
    grafana.enable   = lib.mkEnableOption "Grafana dashboards";
    kafka.enable     = lib.mkEnableOption "Apache Kafka";
    mindsdb.enable   = lib.mkEnableOption "MindsDB ML inferentie laag";
    mlflow.enable    = lib.mkEnableOption "MLflow experiment tracking";
  };

  config = lib.mkMerge [

    # ─── Gitea ──────────────────────────────────────────────────────────────
    (lib.mkIf cfg.gitea.enable {
      services.gitea = {
        enable   = true;
        stateDir = "/data/gitea";
        settings = {
          server = {
            DOMAIN    = "localhost";
            HTTP_PORT = ports.gitea;
            ROOT_URL  = "http://localhost:${toString ports.gitea}";
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
      systemd.tmpfiles.rules = [ "d /data/gitea 0755 gitea gitea -" ];
    })

    # ─── Mosquitto MQTT ─────────────────────────────────────────────────────
    (lib.mkIf cfg.mosquitto.enable {
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
            "user agi_mqtt"
            "topic readwrite agi/#"
          ];
        }];
      };
    })

    # ─── Ollama ─────────────────────────────────────────────────────────────
    (lib.mkIf cfg.ollama.enable {
      services.ollama = {
        enable = true;
        home   = "/data/ollama";
        port   = ports.ollama;
      };
      systemd.tmpfiles.rules = [ "d /data/ollama 0755 reparateur users -" ];
    })

    # ─── n8n ────────────────────────────────────────────────────────────────
    (lib.mkIf cfg.n8n.enable {
      systemd.services.n8n = {
        description = "n8n workflow automatisering";
        wantedBy    = [ "multi-user.target" ];
        after       = [ "network.target" "postgresql.service" ];
        environment = {
          N8N_USER_FOLDER        = "/data/n8n";
          N8N_PORT               = toString ports.n8n;
          N8N_PROTOCOL           = "http";
          N8N_HOST               = "localhost";
          DB_TYPE                = "postgresdb";
          DB_POSTGRESDB_HOST     = "localhost";
          DB_POSTGRESDB_PORT     = toString ports.postgres.primary;
          DB_POSTGRESDB_DATABASE = "n8n";
          DB_POSTGRESDB_USER     = "reparateur";
        };
        serviceConfig = {
          ExecStart        = "${pkgs.n8n}/bin/n8n start";
          Restart          = "on-failure";
          User             = "reparateur";
          WorkingDirectory = "/data/n8n";
          StandardOutput   = "append:/data/logs/n8n/n8n.log";
          StandardError    = "append:/data/logs/n8n/n8n-error.log";
        };
      };
      systemd.tmpfiles.rules = [
        "d /data/n8n          0755 reparateur users -"
        "d /data/logs/n8n     0755 reparateur users -"
      ];
    })

    # ─── Zenoh router ───────────────────────────────────────────────────────
    (lib.mkIf cfg.zenoh.enable {
      environment.systemPackages = [ pkgs.zenoh ];
      systemd.services.zenoh-router = {
        description = "Zenoh message bus router";
        wantedBy    = [ "multi-user.target" ];
        after       = [ "network.target" ];
        serviceConfig = {
          ExecStart      = "${pkgs.zenoh}/bin/zenohd --listen tcp/0.0.0.0:${toString ports.zenoh}";
          Restart        = "on-failure";
          User           = "reparateur";
          StandardOutput = "append:/data/logs/zenoh/zenoh.log";
          StandardError  = "append:/data/logs/zenoh/zenoh-error.log";
        };
      };
      systemd.tmpfiles.rules = [ "d /data/logs/zenoh 0755 reparateur users -" ];
    })

    # ─── Prometheus ─────────────────────────────────────────────────────────
    (lib.mkIf cfg.prometheus.enable {
      services.prometheus = {
        enable  = true;
        port    = ports.prometheus;
        dataDir = "/data/prometheus";
      };
      systemd.tmpfiles.rules = [ "d /data/prometheus 0755 prometheus prometheus -" ];
    })

    # ─── Grafana ────────────────────────────────────────────────────────────
    (lib.mkIf cfg.grafana.enable {
      services.grafana = {
        enable  = true;
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
      systemd.tmpfiles.rules = [ "d /data/grafana 0755 grafana grafana -" ];
    })

    # ─── Kafka ──────────────────────────────────────────────────────────────
    (lib.mkIf cfg.kafka.enable {
      services.apache-kafka = {
        enable = true;
        settings = {
          "listeners"               = "PLAINTEXT://127.0.0.1:${toString ports.kafka.broker}";
          "log.dirs"                = "/data/kafka";
          "zookeeper.connect"       = "127.0.0.1:${toString ports.kafka.zookeeper}";
          "log4j.rootLogger"        = "INFO, file";
          "log4j.appender.file.File" = "/data/logs/kafka/kafka.log";
        };
      };
      systemd.tmpfiles.rules = [
        "d /data/kafka         0755 reparateur users -"
        "d /data/logs/kafka    0755 reparateur users -"
      ];
    })

    # ─── MindsDB ────────────────────────────────────────────────────────────
    (lib.mkIf cfg.mindsdb.enable {
      systemd.services.mindsdb = {
        description = "MindsDB ML inferentie laag";
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
      systemd.tmpfiles.rules = [
        "d /data/mindsdb        0755 reparateur users -"
        "d /data/logs/mindsdb   0755 reparateur users -"
      ];
    })

    # ─── MLflow ─────────────────────────────────────────────────────────────
    (lib.mkIf cfg.mlflow.enable {
      systemd.services.mlflow = {
        description = "MLflow experiment tracking";
        wantedBy    = [ "multi-user.target" ];
        after       = [ "network.target" "postgresql.service" ];
        environment = {
          MLFLOW_BACKEND_STORE_URI     = "postgresql://reparateur@localhost:${toString ports.postgres.primary}/mlflow";
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
      systemd.tmpfiles.rules = [
        "d /data/mlflow            0755 reparateur users -"
        "d /data/mlflow/artifacts  0755 reparateur users -"
        "d /data/logs/mlflow       0755 reparateur users -"
      ];
    })

    # ─── Gedeelde mappen (altijd aanwezig) ──────────────────────────────────
    {
      systemd.tmpfiles.rules = [
        "d /data                       0755 reparateur users -"
        "d /data/logs                  0755 reparateur users -"
        "d /data/snapshots             0755 reparateur users -"
        "d /data/snapshots/klanten     0755 reparateur users -"
        "d /data/snapshots/lab         0755 reparateur users -"
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
  ];
}
