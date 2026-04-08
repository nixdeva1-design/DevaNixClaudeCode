# ─── CuiperHeader ───────────────────────────────────────────────────────────
# ULID:          01COMP029DESKTOP00000000
# Naam:          nixos/modules/CuiperDesktop.nix
# Erft via:      CuiperCore → CuiperDonut
# Aangemaakt:    CuiperStapNr 24
# Gewijzigd:     CuiperStapNr 54 — 2026-04-08
# ────────────────────────────────────────────────────────────────────────────
{ config, pkgs, ... }:

{
  # ─── Display server ───────────────────────────────────────────────────────
  # Wayland met GNOME — vertrouwd voor reparateur, werkt op meeste hardware
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  # Wayland standaard
  services.xserver.displayManager.gdm.wayland = true;

  # ─── Audio ────────────────────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  hardware.pulseaudio.enable = false;

  # ─── Hardware ondersteuning ───────────────────────────────────────────────
  hardware.enableAllFirmware = true;
  services.fwupd.enable = true;

  # Printers (handig bij klanten)
  services.printing.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  # ─── Desktop pakketten ────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # Browser
    firefox

    # Bestanden
    nautilus
    gnome-disk-utility

    # Terminal
    alacritty
    kitty

    # Screenshot / clipboard
    gnome-screenshot
    wl-clipboard

    # Fonts
    noto-fonts
    noto-fonts-emoji
    fira-code
    jetbrains-mono
  ];

  # GNOME extensies uitzetten die niet nodig zijn
  services.gnome.core-utilities.enable = true;

  # ─── Logseq ───────────────────────────────────────────────────────────────
  # Notities per klant — data staat in /data/logseq
  environment.systemPackages = with pkgs; [
    logseq
  ];
}
