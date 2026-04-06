{ config, lib, pkgs, ... }:

# ─── CuiperHyperon — OpenCog Hyperon / MeTTa runtime ──────────────────────
# Hyperon is de opvolger van OpenCog Classic.
# MeTTa (Meta Type Talk) is de programmeertaal voor AGI inferentie.
# Geen Java, geen Python wrapper — native integratie via Rust bindings.
#
# Status: vroeg stadium, broncode wordt gebouwd vanuit source.
# Zodra Nixpkgs een stabiel pakket heeft: vervang fetchFromGitHub door pkgs.hyperon

let
  cfg   = config.cuiper.hyperon;
  ports = config.cuiper.ports;
in

{
  options.cuiper.hyperon = {
    enable = lib.mkEnableOption "OpenCog Hyperon MeTTa runtime";

    dataDir = lib.mkOption {
      type    = lib.types.str;
      default = "/data/hyperon";
      description = "Opslagmap voor Hyperon atomspace en MeTTa bestanden";
    };

    namespace = lib.mkOption {
      type    = lib.types.str;
      default = "agi/hyperon";
      description = "Zenoh namespace voor Hyperon signalen";
    };
  };

  config = lib.mkIf cfg.enable {

    # ─── Hyperon packages — gebouwd vanuit source ──────────────────────
    environment.systemPackages =
      let
        # Hyperon-core is Rust-based — past in ons LEGO model
        # Zodra nixpkgs.hyperon beschikbaar is: verwijder deze override
        hyperonPkg = pkgs.rustPlatform.buildRustPackage {
          pname   = "hyperon";
          version = "0.1.0";

          src = pkgs.fetchFromGitHub {
            owner  = "trueagi-io";
            repo   = "hyperon-experimental";
            rev    = "main";
            sha256 = lib.fakeSha256; # vervang na eerste build: nix-prefetch-url
          };

          cargoHash = lib.fakeHash;

          buildInputs = with pkgs; [ openssl pkg-config ];
          nativeBuildInputs = with pkgs; [ pkg-config ];

          meta = {
            description = "OpenCog Hyperon — AGI inferentie platform";
            license     = lib.licenses.asl20;
          };
        };
      in
      [ hyperonPkg pkgs.python312 ];

    # ─── Hyperon atomspace service ──────────────────────────────────────
    systemd.services.cuiper-hyperon = {
      description = "CuiperHive Hyperon MeTTa runtime";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "network.target" ];

      environment = {
        HYPERON_DATA_DIR = cfg.dataDir;
        HYPERON_NAMESPACE = cfg.namespace;
      };

      serviceConfig = {
        ExecStart      = "${pkgs.bash}/bin/bash -c 'hyperon --data-dir ${cfg.dataDir}'";
        Restart        = "on-failure";
        RestartSec     = "5s";
        User           = "reparateur";
        StandardOutput = "append:/data/logs/hyperon/hyperon.log";
        StandardError  = "append:/data/logs/hyperon/hyperon-error.log";
      };
    };

    # ─── MeTTa bestanden map ────────────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}              0755 reparateur users -"
      "d ${cfg.dataDir}/atomspace    0755 reparateur users -"
      "d ${cfg.dataDir}/metta        0755 reparateur users -"
      "d /data/logs/hyperon          0755 reparateur users -"
    ];
  };
}
