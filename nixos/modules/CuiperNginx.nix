{ config, pkgs, ... }:

{
  # ─── Nginx reverse proxy ──────────────────────────────────────────────────
  # Één ingang voor alle services
  # Internet → Nginx → interne services
  # Niets is direct bereikbaar van buiten

  services.nginx = {
    enable = true;

    # Aanbevolen instellingen
    recommendedGzipSettings  = true;
    recommendedOptimisation  = true;
    recommendedProxySettings = true;
    recommendedTlsSettings   = true;

    # ─── Logging — geen /dev/null ──────────────────────────────────
    appendHttpConfig = ''
      log_format cuiper '$remote_addr [$time_local] '
                        '"$request" $status $body_bytes_sent '
                        '"$http_referer" "$http_user_agent" '
                        'upstream=$upstream_addr';

      access_log /data/logs/nginx/access.log cuiper;
      error_log  /data/logs/nginx/error.log  warn;
    '';

    # ─── Virtual hosts ─────────────────────────────────────────────
    virtualHosts = {

      # Gitea — zelf-gehoste git
      "gitea.localhost" = {
        listen = [{ addr = "0.0.0.0"; port = 80; }];
        locations."/" = {
          proxyPass = "http://127.0.0.1:3000";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };
      };

      # n8n — workflow automatisering
      "n8n.localhost" = {
        listen = [{ addr = "0.0.0.0"; port = 80; }];
        locations."/" = {
          proxyPass = "http://127.0.0.1:5678";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };
      };

      # Grafana — BI dashboards
      "grafana.localhost" = {
        listen = [{ addr = "0.0.0.0"; port = 80; }];
        locations."/" = {
          proxyPass = "http://127.0.0.1:3100";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };
      };

      # Ollama API
      "ollama.localhost" = {
        listen = [{ addr = "0.0.0.0"; port = 80; }];
        locations."/" = {
          proxyPass = "http://127.0.0.1:11434";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            # Grote responses voor model output
            proxy_read_timeout 300s;
            proxy_buffering off;
          '';
        };
      };

      # MindsDB
      "mindsdb.localhost" = {
        listen = [{ addr = "0.0.0.0"; port = 80; }];
        locations."/" = {
          proxyPass = "http://127.0.0.1:47334";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };
      };

      # API gateway — extern toegangspunt
      "api.localhost" = {
        listen = [{ addr = "0.0.0.0"; port = 80; }];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8080";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };
      };
    };
  };

  # ─── Zenoh TCP passthrough via stream proxy ────────────────────────────────
  # Nginx stream module voor Zenoh op poort 7447
  services.nginx.streamConfig = ''
    server {
      listen 7447;
      proxy_pass 127.0.0.1:7447;
      proxy_timeout 3600s;
      proxy_connect_timeout 10s;
      access_log /data/logs/nginx/zenoh-stream.log;
    }
  '';

  # ─── Log map aanmaken ─────────────────────────────────────────────────────
  systemd.tmpfiles.rules = [
    "d /data/logs         0755 nginx nginx -"
    "d /data/logs/nginx   0755 nginx nginx -"
  ];

  # Firewall poorten worden centraal beheerd in system.nix
}
