{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # ─── Rust toolchain ─────────────────────────────────────────────────────
    (rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
    })
    cargo-watch
    cargo-edit
    cargo-expand

    # ─── Python + LangChain omgeving ────────────────────────────────────────
    (python312.withPackages (ps: with ps; [
      langchain
      langchain-community
      langchain-core
      openai          # ook voor Ollama API compatibiliteit
      psycopg2        # PostgreSQL
      pydantic
      fastapi
      uvicorn
      httpx
      rich            # mooie terminal output
      ipython
    ]))

    # ─── Node.js (voor n8n scripts, LangChain JS) ───────────────────────────
    nodejs_22
    nodePackages.npm

    # ─── Claude Code CLI ────────────────────────────────────────────────────
    nodePackages.claude-code

    # ─── Database tools ─────────────────────────────────────────────────────
    postgresql_16     # psql client
    pgcli             # mooiere postgres client

    # ─── Git tools ──────────────────────────────────────────────────────────
    git
    git-lfs
    lazygit           # GUI in terminal

    # ─── Netwerk / reparatie tools ──────────────────────────────────────────
    nmap
    wireshark
    tcpdump
    nettools
    iproute2
    dig
    whois

    # ─── Overige dev tools ──────────────────────────────────────────────────
    jq                # JSON verwerking
    yq                # YAML verwerking
    httpie            # HTTP client
    mosquitto         # MQTT client tools (mosquitto_pub/sub)
    docker-compose
  ];

  # Wireshark zonder root
  programs.wireshark.enable = true;

  # Fish shell configuratie
  programs.fish.enable = true;
}
