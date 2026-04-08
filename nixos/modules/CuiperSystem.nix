# ─── CuiperHeader ───────────────────────────────────────────────────────────
# ULID:          01COMP026SYSTEM0000000000
# Naam:          nixos/modules/CuiperSystem.nix
# Erft via:      CuiperCore → CuiperDonut
# Aangemaakt:    CuiperStapNr 8
# Gewijzigd:     CuiperStapNr 54 — 2026-04-08
# ────────────────────────────────────────────────────────────────────────────
{ config, pkgs, ... }:

{
  # ─── Boot ────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Btrfs compressie voor USB levensduur
  boot.kernelParams = [ "rootflags=compress=zstd" ];

  # ─── Bestandssysteem (btrfs subvolumes) ──────────────────────────────────
  # Structuur op USB:
  #   @          → /          (systeem)
  #   @home      → /home      (gebruiker)
  #   @nix       → /nix       (nix store)
  #   @data      → /data      (databases, app data)
  #   @projects  → /projects  (klant projecten)
  #   @snapshots → /.snapshots
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=@" "compress=zstd" "noatime" "ssd_spread" ];
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" "noatime" ];
  };
  fileSystems."/nix" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  };
  fileSystems."/data" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=@data" "compress=zstd" "noatime" ];
  };
  fileSystems."/projects" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=@projects" "compress=zstd" "noatime" ];
  };
  fileSystems."/.snapshots" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [ "subvol=@snapshots" "noatime" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
  };

  # ─── Gebruiker ───────────────────────────────────────────────────────────
  users.users.reparateur = {
    isNormalUser = true;
    description = "Reparateur";
    extraGroups = [ "wheel" "networkmanager" "docker" "audio" "video" ];
    shell = pkgs.fish;
    # Wachtwoord instellen via: passwd reparateur
    initialPassword = "changeme";
  };

  # ─── Sudo zonder wachtwoord voor wheel ───────────────────────────────────
  security.sudo.wheelNeedsPassword = false;

  # ─── Netwerk ─────────────────────────────────────────────────────────────
  networking = {
    hostName = "reparatie-usb";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        # Standaard internet verkeer
        80    # HTTP  — Nginx reverse proxy
        443   # HTTPS — Nginx reverse proxy

        # Beheer
        22    # SSH

        # Services — direct of via Nginx (zie CuiperNginx.nix voor vhosts)
        3001  # Gitea          (CuiperPorts: gitea = 3001)
        5678  # n8n
        3100  # Grafana
        11434 # Ollama
        47334 # MindsDB HTTP

        # Messaging bus
        7447  # Zenoh TCP

        # Database — alleen lokaal, nooit via firewall naar buiten
        # 5432 PostgreSQL — bewust weggelaten, alleen via Unix socket / localhost
        # 27017 MongoDB    — bewust weggelaten, alleen via localhost
        # 6379 Redis       — bewust weggelaten, alleen via localhost

        # Jaeger poorten worden beheerd door CuiperJaeger.nix zelf
      ];

      # Uitgaand verkeer nooit blokkeren
      # USB surft normaal internet via host netwerk
      allowedUDPPorts = [
        7447  # Zenoh UDP
      ];
    };
  };

  # ─── Tijdzone & taal ─────────────────────────────────────────────────────
  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "nl_NL.UTF-8";
  console.keyMap = "us";

  # ─── Nix instellingen ────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  # ─── Basis systeem pakketten ─────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    htop
    btop
    fish
    tmux
    unzip
    zip
    rsync
    usbutils
    pciutils
    parted
    gparted
    smartmontools   # schijf gezondheid
    testdisk        # schijf herstel
    nmap            # netwerk scan
    openssh
    gnupg
  ];

  # ─── SSH ─────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # ─── Docker (voor n8n, langchain containers) ─────────────────────────────
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      "data-root" = "/data/docker";
    };
  };

  system.stateVersion = "24.11";
}
