# ─── CuiperHeader ───────────────────────────────────────────────────────────
# ULID:          01COMP031HOME000000000000
# Naam:          nixos/home/default.nix
# Erft via:      CuiperCore → CuiperDonut
# Aangemaakt:    CuiperStapNr 24
# Gewijzigd:     CuiperStapNr 54 — 2026-04-08
# ────────────────────────────────────────────────────────────────────────────
{ config, pkgs, lib, ... }:

{
  home.username = "reparateur";
  home.homeDirectory = "/home/reparateur";
  home.stateVersion = "24.11";

  # ─── Neovim ───────────────────────────────────────────────────────────────
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    plugins = with pkgs.vimPlugins; [
      # LSP
      nvim-lspconfig
      # Syntax highlighting
      nvim-treesitter.withAllGrammars
      # Bestandsnavigatie
      telescope-nvim
      telescope-fzf-native-nvim
      # Git integratie
      gitsigns-nvim
      lazygit-nvim
      # Statusbalk
      lualine-nvim
      # Bestandsboom
      nvim-tree-lua
      nvim-web-devicons
      # Autocomplete
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      luasnip
      # Thema
      catppuccin-nvim
      # Rust specifiek
      rust-tools-nvim
      # Commentaar
      comment-nvim
      # Auto paren
      nvim-autopairs
    ];

    extraLuaConfig = builtins.readFile ./neovim/init.lua;
  };

  # ─── Git ──────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    userName = "Reparateur";
    userEmail = "jouw@email.nl";  # aanpassen
    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  # ─── Fish shell ───────────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    shellAliases = {
      # Navigatie
      proj = "cd /projects";
      lab  = "cd /lab/projecten";
      data = "cd /data";

      # NixOS beheer
      rebuild = "sudo nixos-rebuild switch --flake /home/reparateur/.config/nixos#reparatie-usb";
      update  = "nix flake update /home/reparateur/.config/nixos";

      # Klant werkplek (gescheiden van lab)
      nieuw-klant    = "/home/reparateur/.config/nixos/scripts/CuiperNieuweKlant.sh";

      # Lab project (gescheiden van klanten)
      nieuw-project  = "/home/reparateur/.config/nixos/scripts/CuiperNieuwLabProject.sh";

      # Services
      db    = "pgcli -U reparateur";
      gitea = "xdg-open http://localhost:3001";  # CuiperPorts: gitea = 3001
      n8n   = "xdg-open http://localhost:5678";

      # Snapshots / debug
      snap       = "/home/reparateur/.config/nixos/scripts/CuiperSnapshot.sh maak";
      snaps      = "/home/reparateur/.config/nixos/scripts/CuiperSnapshot.sh lijst";
      herstel    = "/home/reparateur/.config/nixos/scripts/CuiperSnapshot.sh herstel";

      # Air-gap test omgeving
      airgap     = "cd /airgap/tests";

      # Ollama
      ai    = "ollama run mistral";
      chat  = "ollama run llama3.2";

      # Logs
      logs  = "journalctl -f";
    };

    interactiveShellInit = ''
      # API key voor Claude Code (pas aan met jouw key)
      # set -x ANTHROPIC_API_KEY "sk-ant-..."

      # Welkomstbericht
      echo "Reparatie USB - klaar voor gebruik"
      echo "nieuw-klant <naam>  → nieuwe klantmap aanmaken"
      echo "proj               → naar /projects"
    '';
  };

  # ─── Alacritty terminal ───────────────────────────────────────────────────
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal.family = "JetBrains Mono";
        size = 13;
      };
      colors.primary = {
        background = "#1e1e2e";
        foreground = "#cdd6f4";
      };
    };
  };

  # ─── Logseq data map ──────────────────────────────────────────────────────
  # Logseq vault staat in /data/logseq zodat notities bewaard blijven
  home.file.".logseq-data".text = "/data/logseq";

  # ─── API key bestand (template) ───────────────────────────────────────────
  home.file.".config/claude/.env.template".text = ''
    # Kopieer dit naar .env en vul jouw key in
    # cp ~/.config/claude/.env.template ~/.config/claude/.env
    ANTHROPIC_API_KEY=sk-ant-JOUW_KEY_HIER
  '';

  programs.home-manager.enable = true;
}
