{ config, lib, pkgs, ... }:

let
  cfg   = config.cuiper.services;
  ports = config.cuiper.ports;
in

{
  # ─── Nginx enable optie ───────────────────────────────────────────────────
  options.cuiper.nginx.enable = lib.mkEnableOption "Nginx reverse proxy";

  config = lib.mkIf config.cuiper.nginx.enable {

    services.nginx = {
      enable = true;

      recommendedGzipSettings  = true;
      recommendedOptimisation  = true;
      recommendedProxySettings = true;
      recommendedTlsSettings   = true;

      # ─── Logging — geen /dev/null ────────────────────────────────────
      appendHttpConfig = ''
        log_format cuiper '$remote_addr [$time_local] '
                          '"$request" $status $body_bytes_sent '
                          '"$http_referer" "$http_user_agent" '
                          'upstream=$upstream_addr';

        access_log /data/logs/nginx/access.log cuiper;
        error_log  /data/logs/nginx/error.log  warn;
      '';

      # ─── Virtual hosts — conditioneel op welke services actief zijn ──
      virtualHosts = lib.mkMerge [

        (lib.mkIf cfg.gitea.enable {
          "gitea.localhost" = {
            listen    = [{ addr = "0.0.0.0"; port = 80; }];
            locations."/" = {
              proxyPass       = "http://127.0.0.1:${toString ports.gitea}";
              proxyWebsockets = true;
            };
          };
        })

        (lib.mkIf cfg.n8n.enable {
          "n8n.localhost" = {
            listen    = [{ addr = "0.0.0.0"; port = 80; }];
            locations."/" = {
              proxyPass       = "http://127.0.0.1:${toString ports.n8n}";
              proxyWebsockets = true;
            };
          };
        })

        (lib.mkIf cfg.grafana.enable {
          "grafana.localhost" = {
            listen    = [{ addr = "0.0.0.0"; port = 80; }];
            locations."/" = {
              proxyPass       = "http://127.0.0.1:${toString ports.grafana}";
              proxyWebsockets = true;
            };
          };
        })

        (lib.mkIf cfg.ollama.enable {
          "ollama.localhost" = {
            listen    = [{ addr = "0.0.0.0"; port = 80; }];
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString ports.ollama}";
              extraConfig = ''
                proxy_read_timeout 300s;
                proxy_buffering off;
              '';
            };
          };
        })

        (lib.mkIf cfg.mindsdb.enable {
          "mindsdb.localhost" = {
            listen    = [{ addr = "0.0.0.0"; port = 80; }];
            locations."/" = {
              proxyPass       = "http://127.0.0.1:${toString ports.mindsdb.http}";
              proxyWebsockets = true;
            };
          };
        })

        (lib.mkIf cfg.mlflow.enable {
          "mlflow.localhost" = {
            listen    = [{ addr = "0.0.0.0"; port = 80; }];
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString ports.mlflow}";
            };
          };
        })

      ];

      # ─── Zenoh TCP passthrough via stream proxy ─────────────────────
      streamConfig = lib.mkIf cfg.zenoh.enable ''
        server {
          listen ${toString ports.zenoh};
          proxy_pass 127.0.0.1:${toString ports.zenoh};
          proxy_timeout 3600s;
          proxy_connect_timeout 10s;
          access_log /data/logs/nginx/zenoh-stream.log;
        }
      '';
    };

    systemd.tmpfiles.rules = [
      "d /data/logs       0755 nginx nginx -"
      "d /data/logs/nginx 0755 nginx nginx -"
    ];
  };
}
