{ config, lib, pkgs, ... }:

let
  cfg   = config.cuiper.jaeger;
  ports = config.cuiper.ports;
in

{
  # ─── CuiperJaeger — distributed tracing voor CuiperHive ─────────────────
  # Alle uitvoeringen via CuiperListener.sh produceren Jaeger spans.
  # Jaeger all-in-one: agent + collector + query + UI in één proces.
  # UI bereikbaar op: http://localhost:<ports.jaeger.ui>

  options.cuiper.jaeger = {
    enable = lib.mkEnableOption "Jaeger distributed tracing";

    dataDir = lib.mkOption {
      type    = lib.types.str;
      default = "/data/jaeger";
      description = "Opslagmap voor Jaeger traces (badger backend)";
    };

    bewaartermijn = lib.mkOption {
      type    = lib.types.str;
      default = "168h"; # 7 dagen
      description = "Hoe lang traces bewaard worden";
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [ pkgs.jaeger ];

    systemd.services.cuiper-jaeger = {
      description = "CuiperHive Jaeger tracing (all-in-one)";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "network.target" ];

      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.jaeger}/bin/jaeger-all-in-one"
          "--collector.otlp.enabled=true"
          "--collector.otlp.http.host-port=0.0.0.0:${toString ports.jaeger.otlp-http}"
          "--collector.otlp.grpc.host-port=0.0.0.0:${toString ports.jaeger.otlp-grpc}"
          "--collector.http-server.host-port=0.0.0.0:${toString ports.jaeger.collector-http}"
          "--query.http-server.host-port=0.0.0.0:${toString ports.jaeger.ui}"
          "--span-storage.type=badger"
          "--badger.ephemeral=false"
          "--badger.directory-value=${cfg.dataDir}/values"
          "--badger.directory-key=${cfg.dataDir}/keys"
          "--badger.maintenance-interval=30s"
          "--log-level=info"
        ];

        Restart          = "on-failure";
        RestartSec       = "5s";
        User             = "reparateur";
        StandardOutput   = "append:/data/logs/jaeger/jaeger.log";
        StandardError    = "append:/data/logs/jaeger/jaeger-error.log";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}         0755 reparateur users -"
      "d ${cfg.dataDir}/values  0755 reparateur users -"
      "d ${cfg.dataDir}/keys    0755 reparateur users -"
      "d /data/logs/jaeger      0755 reparateur users -"
    ];

    # ─── Firewall: Jaeger poorten alleen lokaal ───────────────────────
    # UI is bereikbaar via Nginx proxy op jaeger.localhost
    networking.firewall.allowedTCPPorts = [
      ports.jaeger.ui
      ports.jaeger.otlp-http
      ports.jaeger.collector-http
    ];
    networking.firewall.allowedUDPPorts = [
      ports.jaeger.agent-compact
    ];
  };
}
