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
        22    # SSH
        80    # HTTP
        443   # HTTPS
        3000  # Gitea
        5432  # PostgreSQL (lokaal)
        5678  # n8n
        1883  # MQTT
        7447  # Zenoh
        11434 # Ollama
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
