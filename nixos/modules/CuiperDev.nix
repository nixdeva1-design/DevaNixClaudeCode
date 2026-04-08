{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [

    # ─── MACHINE LAAG ────────────────────────────────────────────────────────

    # Assembler
    nasm                # NASM x86/x64 assembler
    fasm                # FASM flat assembler
    yasm                # YASM assembler

    # C / C++ toolchain
    gcc                 # GNU C compiler
    clang               # LLVM C compiler
    llvm                # LLVM toolchain
    cmake               # build systeem
    gnumake             # make
    pkg-config          # library configuratie
    gdb                 # GNU debugger op machine niveau
    valgrind            # geheugen analyse
    strace              # system calls traceren
    ltrace              # library calls traceren

    # Binaire inspectie / reverse engineering
    binutils            # objdump, nm, readelf, ld, as
    hexyl               # hex viewer met kleur
    xxd                 # hex dump
    radare2             # reverse engineering, hex, assembler analyse
    file                # bestandstype detectie
    strings             # strings uit binaire bestanden

    # Fortran
    gfortran            # GNU Fortran compiler

    # Pascal / Delphi
    fpc                 # Free Pascal Compiler — Delphi compatibel

    # ─── RUST TOOLCHAIN ──────────────────────────────────────────────────────
    (rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
    })
    cargo-watch
    cargo-edit
    cargo-expand
    cargo-flamegraph    # performance profiling
    cargo-audit         # security audit

    # ─── PYTHON + LANGCHAIN ──────────────────────────────────────────────────
    (python312.withPackages (ps: with ps; [
      langchain
      langchain-community
      langchain-core
      openai
      psycopg2
      pydantic
      fastapi
      uvicorn
      httpx
      rich
      ipython
      numpy               # numeriek, Fortran interop
      scipy               # wetenschappelijk
      cffi                # C Foreign Function Interface
    ]))

    # ─── NODE.JS ─────────────────────────────────────────────────────────────
    nodejs_22
    nodePackages.npm

    # ─── CLAUDE CODE CLI ─────────────────────────────────────────────────────
    nodePackages.claude-code

    # ─── DATABASE TOOLS ──────────────────────────────────────────────────────
    postgresql_16
    pgcli
    dbeaver-bin         # universele database GUI

    # ─── GIT ─────────────────────────────────────────────────────────────────
    git
    git-lfs
    lazygit
    delta               # git diff viewer

    # ─── NETWERK / REPARATIE ─────────────────────────────────────────────────
    nmap
    wireshark
    tcpdump
    nettools
    iproute2
    dig
    whois

    # ─── OVERIGE DEV TOOLS ───────────────────────────────────────────────────
    jq
    yq
    httpie
    mosquitto
    docker-compose
    ripgrep             # snelle code zoeker
    fd                  # snelle bestandszoeker
    bat                 # cat met syntax highlighting
    tokei               # code statistieken per taal

  ];

  # ─── VSCODIUM ────────────────────────────────────────────────────────────
  # Open source VSCode zonder telemetrie
  # Compatibel met Neovim via gedeelde LSP servers
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    extensions = with pkgs.vscode-extensions; [
      # Rust
      rust-lang.rust-analyzer
      # C/C++
      ms-vscode.cpptools
      # Python
      ms-python.python
      # Nix
      jnoortheen.nix-ide
      # Git
      eamodio.gitlens
      # Hex editor
      ms-vscode.hexeditor
      # Thema
      catppuccin.catppuccin-vsc
    ];
    userSettings = {
      "editor.fontFamily"     = "'JetBrains Mono', monospace";
      "editor.fontSize"       = 14;
      "editor.formatOnSave"   = true;
      "editor.tabSize"        = 2;
      "workbench.colorTheme"  = "Catppuccin Mocha";
      # LSP servers gedeeld met Neovim
      "rust-analyzer.server.path" = "${pkgs.rust-analyzer}/bin/rust-analyzer";
      "clangd.path"               = "${pkgs.clang-tools}/bin/clangd";
      "nix.serverPath"            = "${pkgs.nil}/bin/nil";
    };
  };

  # ─── NEOVIM LSP SERVERS (gedeeld met VSCodium) ───────────────────────────
  # Beide editors gebruiken dezelfde LSP servers — compatibel
  environment.systemPackages = with pkgs; [
    # LSP servers
    rust-analyzer           # Rust — gedeeld Neovim + VSCodium
    clang-tools             # clangd voor C/C++ — gedeeld
    nil                     # Nix LSP — gedeeld
    pyright                 # Python LSP — gedeeld
    lua-language-server     # Lua LSP voor Neovim config zelf
    nodePackages.typescript-language-server  # TS/JS

    # Assembler LSP (experimenteel)
    asm-lsp                 # ASM language server

    # Pascal LSP
    # fpc heeft eigen tooling — via AsmDebugger in VSCodium

    # Fortran LSP
    fortls                  # Fortran Language Server
  ];

  # ─── WIRESHARK ZONDER ROOT ────────────────────────────────────────────────
  programs.wireshark.enable = true;

  # ─── FISH SHELL ──────────────────────────────────────────────────────────
  programs.fish.enable = true;
}
