# CuiperHive Klantprofiel: ai-werkstation
# Focus: Ollama + MindsDB + MLflow + Neo4j
# Geen: Kafka, Mosquitto, n8n, MongoDB, PHP, Ruby
# Gebruik: nixos-rebuild switch --flake .#ai-werkstation

{ ... }:

{
  cuiper.services = {
    gitea.enable      = true;
    mosquitto.enable  = false;
    ollama.enable     = true;
    n8n.enable        = false;
    zenoh.enable      = true;
    prometheus.enable = true;
    grafana.enable    = true;
    kafka.enable      = false;
    mindsdb.enable    = true;
    mlflow.enable     = true;
  };

  cuiper.databases = {
    postgres.enable = true;
    mongodb.enable  = false;
    redis.enable    = true;
    neo4j.enable    = true;
    duckdb.enable   = true;
    phpfpm.enable   = false;
    ruby.enable     = false;
  };

  cuiper.nginx.enable = true;
}
