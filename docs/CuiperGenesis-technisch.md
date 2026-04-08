# CuiperGenesis — Deel III: Technisch Ontwerp
# Regelnummers zijn stabiele referenties. Nooit verwijderen. Alleen aanvullen via amendement.
# Aangemaakt: CuiperStapNr 42 — ULID: 01JWTFKN3GENESIS — 2026-04-07
#
# Dit document beschrijft HOE het systeem gebouwd is.
# Het WAT staat in CuiperGenesis-functioneel.md.
# Het WAAROM staat in CuiperGenesis-filosofie.md.

## TO.001 — Repository Structuur

TO.001.01  /home/user/DevaNixClaudeCode/
TO.001.02    Cargo.toml              — Rust workspace (cuiper-core, cuiper-bus, cuiper-datalog, cuiper-router)
TO.001.03    CuiperConfig.env        — Centrale config, alle scripts sourcen dit
TO.001.04    CLAUDE.md               — Protocol geladen bij elke sessie
TO.001.05    flake.lock              — Nix dependency lock
TO.001.06
TO.001.07    backlog/
TO.001.08      CuiperBacklog.md                — Backlog van alle taken
TO.001.09      CuiperClaudeCodeTakenlijst.md   — Mandaten van ClaudeCode
TO.001.10
TO.001.11    crates/
TO.001.12      cuiper-core/          — Kern types (Cuip, Bewaker, Entiteit, Donut, Markov)
TO.001.13      cuiper-bus/           — Zenoh namespace wrapper
TO.001.14      cuiper-datalog/       — Forward-chaining Datalog engine
TO.001.15      cuiper-router/        — Namespace-gebaseerde signaal routing
TO.001.16
TO.001.17    docs/
TO.001.18      CuiperGenesis-filosofie.md      — Deel I
TO.001.19      CuiperGenesis-functioneel.md    — Deel II
TO.001.20      CuiperGenesis-technisch.md      — Deel III (dit bestand)
TO.001.21      CuiperGenesis-bouwplan.md       — Deel IV
TO.001.22
TO.001.23    logs/
TO.001.24      trail/                — Alle trail logs (ULID.log per stap)
TO.001.25      prompts/              — Prompt export (JSON + JSONL)
TO.001.26
TO.001.27    nixos/
TO.001.28      flake.nix             — Multi-client NixOS configuraties
TO.001.29      modules/              — 9 opt-in NixOS modules
TO.001.30      clients/              — 3 klantprofielen
TO.001.31      db/                   — PostgreSQL init scripts
TO.001.32      home/                 — Home Manager configuratie
TO.001.33      projects/             — Project-specifieke configs
TO.001.34
TO.001.35    ontologie/
TO.001.36      CuiperHiveCoreOntologie.sql     — Hive leden, componenten, verbindingen
TO.001.37
TO.001.38    scripts/
TO.001.39      protocol/             — Alle protocol scripts

## TO.002 — CuiperConfig.env

TO.002.01  Alle scripts sourcen dit bestand als eerste actie.
TO.002.02  Geen hardcoded paden toegestaan in scripts.
TO.002.03
TO.002.04  CUIPER_REPO="$(git rev-parse --show-toplevel)"
TO.002.05  CUIPER_BRANCH="$(git branch --show-current)"
TO.002.06  CUIPER_NAMESPACE="${CUIPER_NAMESPACE:-standaard}"
TO.002.07  CUIPER_CLIENT_ID="${CUIPER_CLIENT_ID:-standaard}"
TO.002.08  CUIPER_TRAIL_DIR="$CUIPER_REPO/logs/trail"
TO.002.09  CUIPER_BACKLOG_DIR="$CUIPER_REPO/backlog"
TO.002.10  CUIPER_SCRIPTS_DIR="$CUIPER_REPO/scripts"
TO.002.11  CUIPER_LOG_DIR="$CUIPER_REPO/logs"
TO.002.12  CUIPER_JAEGER_OTLP_URL="${CUIPER_JAEGER_OTLP_URL:-http://127.0.0.1:4318}"

## TO.003 — NixOS Module Architectuur

TO.003.01  Elke NixOS module volgt hetzelfde patroon:
TO.003.02
TO.003.03    { lib, config, pkgs, ... }:
TO.003.04    let cfg = config.cuiper.services.<naam>; in
TO.003.05    {
TO.003.06      options.cuiper.services.<naam>.enable =
TO.003.07        lib.mkEnableOption "CuiperHive <naam> service";
TO.003.08
TO.003.09      config = lib.mkIf cfg.enable {
TO.003.10        # service configuratie
TO.003.11      };
TO.003.12    }
TO.003.13
TO.003.14  Modules (9 totaal):
TO.003.15    CuiperPorts.nix      — Centrale poortregistry (geen service, altijd geladen)
TO.003.16    CuiperSystem.nix     — Basis systeem (bootloader, locale, users)
TO.003.17    CuiperDesktop.nix    — GUI (Plasma 6, Wayland)
TO.003.18    CuiperDev.nix        — Dev tools (Neovim, VSCodium, Rust, Git)
TO.003.19    CuiperServices.nix   — Services (Gitea, n8n, MindsDB, Kafka, Ollama)
TO.003.20    CuiperDatabases.nix  — Databases (PostgreSQL, Neo4j, MongoDB, DuckDB)
TO.003.21    CuiperNginx.nix      — Reverse proxy (vhosts per actieve service)
TO.003.22    CuiperJaeger.nix     — Distributed tracing (all-in-one, badger storage)
TO.003.23    CuiperHyperon.nix    — OpenCog Hyperon (MeTTa, AtomSpace)
TO.003.24
TO.003.25  Poortregistry (CuiperPorts.nix) — stabiele referentie:
TO.003.26    postgresql  = 5432
TO.003.27    neo4j.bolt  = 7687  neo4j.http = 7474
TO.003.28    mongodb     = 27017
TO.003.29    redis       = 6379
TO.003.30    gitea       = 3000
TO.003.31    n8n         = 5678
TO.003.32    ollama      = 11434
TO.003.33    mindsdb     = 47334
TO.003.34    mlflow      = 5000
TO.003.35    jaeger.ui   = 16686  jaeger.otlp-http = 4318  jaeger.otlp-grpc = 4317
TO.003.36    zenoh       = 7447

## TO.004 — flake.nix mkCuiperSystem Helper

TO.004.01  De mkCuiperSystem functie bouwt een volledig NixOS systeem uit:
TO.004.02    — de basismodules (altijd geladen)
TO.004.03    — één klantprofiel (bepaalt welke services actief zijn)
TO.004.04
TO.004.05  mkCuiperSystem = klantProfiel:
TO.004.06    nixpkgs.lib.nixosSystem {
TO.004.07      inherit system;
TO.004.08      modules = basisModules ++ [ klantProfiel ];
TO.004.09    };
TO.004.10
TO.004.11  nixosConfigurations = {
TO.004.12    standaard     = mkCuiperSystem ./clients/standaard.nix;
TO.004.13    ai-werkstation = mkCuiperSystem ./clients/ai-werkstation.nix;
TO.004.14    minimal       = mkCuiperSystem ./clients/minimal.nix;
TO.004.15  };

## TO.005 — Rust Workspace

TO.005.01  Workspace definitie (Cargo.toml):
TO.005.02    members = ["cuiper-core", "cuiper-bus", "cuiper-datalog", "cuiper-router"]
TO.005.03    resolver = "2"
TO.005.04
TO.005.05  Crate 1: cuiper-core
TO.005.06    Pad: crates/cuiper-core/
TO.005.07    Modules: donut, cuip, bewaker, entiteit, hive, mandaat, markov, tests
TO.005.08    Sleutel types:
TO.005.09      CuiperDonut (trait)     — erfenis-methode, geweten(), passeer_ring()
TO.005.10      CuipWaarde (enum)       — Can | Voltooid | Mislukt(String) | Gesedimenteerd
TO.005.11      CuiperCuip (struct)     — ULID + timestamp + regelnr + omschrijving + waarde
TO.005.12      CuiperBewaker (struct)  — idempotentie, timeout, loop-limiet, Markov
TO.005.13      CuiperEntiteit (struct) — nr + naam + karakter + archetype + geschiedenis
TO.005.14      CuiperMarkovState       — A | B | C transitie
TO.005.15      WetSchending (struct)   — wet + actie + component, impl Display + Error
TO.005.16
TO.005.17  Crate 2: cuiper-bus
TO.005.18    Pad: crates/cuiper-bus/
TO.005.19    Doel: Zenoh bus wrapper met namespace-isolatie
TO.005.20    Sleutel type: CuiperSignaal { key, payload, timestamp, afzender }
TO.005.21
TO.005.22  Crate 3: cuiper-datalog
TO.005.23    Pad: crates/cuiper-datalog/
TO.005.24    Doel: Forward-chaining semi-naïve Datalog engine in Rust
TO.005.25    Geen Java. Geen externe JVM.
TO.005.26    Sleutel types: CuiperFeit, CuiperRegel, CuiperDatalogMotor
TO.005.27    Methode: itereer totdat vaste punt bereikt (geen nieuwe feiten meer)
TO.005.28
TO.005.29  Crate 4: cuiper-router
TO.005.30    Pad: crates/cuiper-router/
TO.005.31    Doel: Namespace-gebaseerde signaal routing met airgap isolatie
TO.005.32    Sleutel types:
TO.005.33      CuiperRouteRegel        — patroon (**, /*), actie, prioriteit
TO.005.34      CuiperNaamspaceBrug     — expliciete brug voor cross-namespace
TO.005.35      CuiperRouter            — routing log (elk besluit gesedimenteerd)
TO.005.36    Patroon matching:
TO.005.37      klant/**  = alles onder klant/
TO.005.38      klant/*   = exact één niveau onder klant/
TO.005.39      klant/acme/sensor = exacte match
TO.005.40    Fouten: NamespaceSchending | AirgapSchending | GeenRoute | BrugOntbreekt

## TO.006 — Protocol Scripts

TO.006.01  Pad: scripts/protocol/
TO.006.02  Alle scripts sourcen CuiperConfig.env als eerste actie.
TO.006.03  Geen 2>/dev/null. Fouten gaan naar trail log via log_fout().
TO.006.04
TO.006.05  Script 1: CuiperPromptCounter.sh (Stop hook)
TO.006.06    Getriggerd als: stop hook na elke respons
TO.006.07    Acties:
TO.006.08      1. Lees sessie open timestamp uit SESSIE_OPEN log
TO.006.09      2. Vergelijk met counter timestamp → bepaal nieuwe sessie of niet
TO.006.10      3. Verhoog counter
TO.006.11      4. Stuur Jaeger span via CuiperJaegerSpan.sh
TO.006.12      5. Controleer drempel (avg*0.80 zacht, avg*0.95 hard)
TO.006.13      6. Auto-commit + push logs/trail/ (4x retry exponentieel)
TO.006.14
TO.006.15  Script 2: CuiperKlaarMelding.sh
TO.006.16    Args: <ulid> <stapnr>
TO.006.17    Toont: StapNr, ULID, commit, branch, sessie teller, backlog counts
TO.006.18    Verplicht: altijd als laatste actie van elke ClaudeCode respons
TO.006.19
TO.006.20  Script 3: CuiperBacklogPlanner.sh
TO.006.21    Commando's:
TO.006.22      toevoegen <id> <prio> <omschrijving>  — nieuw item
TO.006.23      status    <id> <status>               — status wijzigen
TO.006.24      prioriteit <id> <prio>                — prioriteit wijzigen
TO.006.25      samenvatting                          — counts per prioriteit
TO.006.26      toon                                  — volledige lijst
TO.006.27    Elke mutatie: commit + push automatisch
TO.006.28
TO.006.29  Script 4: CuiperListener.sh
TO.006.30    Args: --exec <cmd> --naam <naam> --stap <nr>
TO.006.31    Acties:
TO.006.32      1. Genereer trace_id + span_id (hex random)
TO.006.33      2. Record start timestamp
TO.006.34      3. Voer commando uit, vang stdout+stderr op → trail log
TO.006.35      4. Record eind timestamp
TO.006.36      5. Stuur OTLP span naar Jaeger via CuiperJaegerSpan.sh
TO.006.37      6. Log Markov uitkomst: C==B (exit 0) | C!=B (exit !=0)
TO.006.38
TO.006.39  Script 5: CuiperJaegerSpan.sh
TO.006.40    Gedeelde Jaeger OTLP HTTP span sender
TO.006.41    Args: --trace --span --naam --start --eind --status --stap --exit
TO.006.42    Bij verbindingsfout: log naar trail, nooit abort
TO.006.43
TO.006.44  Script 6: CuiperPromptExporter.sh
TO.006.45    Exporteert sessie JSONL naar logs/prompts/ als JSON + JSONL
TO.006.46    Args: --sessie <uuid> | --alle | standaard = nieuwste sessie
TO.006.47    Probleem: compaction maakt vroege berichten niet meer extracteerbaar
TO.006.48    Oplossing: exporteer elke sessie direct na aanmaken

## TO.007 — Ontologie Schema

TO.007.01  Bestand: ontologie/CuiperHiveCoreOntologie.sql
TO.007.02  Database: PostgreSQL (poort 5432)
TO.007.03
TO.007.04  Tabel 1: cuiper_hive_lid
TO.007.05    hive_nr (PK), naam, rol, mandaat, karakter, archetype, status, ulid, timestamps
TO.007.06    5 rijen: Nul(0), Cuiper(1), Deva(2), ClaudeCode(3), Claude.ai(4)
TO.007.07    Wet: nooit verwijderen, alleen amenderen (UPDATE gewijzigd)
TO.007.08
TO.007.09  Tabel 2: cuiper_hive_component
TO.007.10    ulid (PK), naam, type, pad, beschrijving, eigenaar_hive_nr, erft_van, status, timestamps
TO.007.11    erft_van verwijst naar cuiper_hive_component(ulid) — de erfenis-keten
TO.007.12    24 componenten geregistreerd (stap 42)
TO.007.13    type waarden: script | nix-module | rust-crate | sql-schema | config | register | mandaat
TO.007.14
TO.007.15  Tabel 3: cuiper_hive_verbinding
TO.007.16    ulid (PK), van_ulid, naar_ulid, type, beschrijving, aangemaakt
TO.007.17    type waarden: gebruikt | roept-aan | produceert | configureert | bewaakt | tracet | implementeert
TO.007.18    13 verbindingen geregistreerd (stap 42)
TO.007.19
TO.007.20  Tabel 4: cuiper_listener_trace
TO.007.21    ulid (PK), component_ulid, trace_id (Jaeger), span_id, stap_nr,
TO.007.22    exit_code, duur_seconden, markov_uitkomst (C==B | C!=B), uitgevoerd
TO.007.23    Elke CuiperListener.sh uitvoering maakt een rij aan

## TO.008 — Jaeger Distributed Tracing

TO.008.01  Jaeger all-in-one: één binary, badger storage, geen Cassandra/Elasticsearch nodig.
TO.008.02  NixOS module: nixos/modules/CuiperJaeger.nix (opt-in)
TO.008.03
TO.008.04  Poorten:
TO.008.05    4318 — OTLP HTTP (ontvang spans)
TO.008.06    4317 — OTLP gRPC
TO.008.07    16686 — Jaeger UI (browser)
TO.008.08    14268 — Collector HTTP (legacy)
TO.008.09
TO.008.10  Elke CuiperListener.sh uitvoering stuurt een span:
TO.008.11    trace_id: 32 hex chars (willekeurig gegenereerd)
TO.008.12    span_id:  16 hex chars
TO.008.13    service.name: "CuiperHive"
TO.008.14    tags: stap_nr, component naam, exit code, markov uitkomst
TO.008.15
TO.008.16  Verbinding: CuiperJaegerSpan.sh → HTTP POST → localhost:4318/v1/traces
TO.008.17  Bij verbindingsfout: log naar trail, ga door. Nooit abort.

## TO.009 — Git Workflow en Branch Strategie

TO.009.01  Primaire branch: claude/linux-usb-dual-boot-Hsk67
TO.009.02  Remote: http://127.0.0.1:<poort>/git/nixdeva1-design/DevaNixClaudeCode
TO.009.03
TO.009.04  Regels:
TO.009.05    — Elke stap = één commit. Nooit meerdere stappen in één commit.
TO.009.06    — Commit message bevat altijd: CuiperStapNr + beschrijving + session URL
TO.009.07    — Push na elke commit. 4x retry met exponentieel backoff (2s, 4s, 8s, 16s)
TO.009.08    — Nooit force-push. Nooit --no-verify.
TO.009.09    — Bij branch divergentie: fetch + rebase, nooit merge.
TO.009.10
TO.009.11  Stop hook (.claude/settings.json):
TO.009.12    Triggert CuiperPromptCounter.sh na elke Claude respons.
TO.009.13    Auto-commit + push van logs/trail/ als er uncommitted files zijn.

## TO.010 — Regeneratieprotocol

TO.010.01  Dit protocol beschrijft hoe het systeem volledig herbouwd kan worden.
TO.010.02  Situatie: nieuwe machine, lege schijf, alleen git remote beschikbaar.
TO.010.03
TO.010.04  Stap 1: Clone repository
TO.010.05    git clone <remote-url> DevaNixClaudeCode
TO.010.06    cd DevaNixClaudeCode
TO.010.07    git checkout claude/linux-usb-dual-boot-Hsk67
TO.010.08
TO.010.09  Stap 2: Lees de genesis documenten
TO.010.10    docs/CuiperGenesis-filosofie.md   → begrijp het WAAROM
TO.010.11    docs/CuiperGenesis-functioneel.md → begrijp het WAT
TO.010.12    docs/CuiperGenesis-technisch.md   → begrijp het HOE
TO.010.13    docs/CuiperGenesis-bouwplan.md    → begrijp de VOLGORDE
TO.010.14
TO.010.15  Stap 3: Installeer NixOS
TO.010.16    nixos-rebuild switch --flake .#<klantprofiel>
TO.010.17
TO.010.18  Stap 4: Bouw Rust crates
TO.010.19    cargo build --workspace
TO.010.20    cargo test --workspace
TO.010.21
TO.010.22  Stap 5: Laad ontologie in PostgreSQL
TO.010.23    psql -U postgres -d cuiperhive -f ontologie/CuiperHiveCoreOntologie.sql
TO.010.24
TO.010.25  Stap 6: Verifieer protocol scripts
TO.010.26    bash scripts/protocol/CuiperKlaarMelding.sh TEST 0
TO.010.27
TO.010.28  Het systeem is volledig herbouwd. Alle kennis is bewaard in de repository.
TO.010.29  Dit is de garantie van sedimentatie: als het gepusht is, kan het herbouwd worden.

---
## AMENDEMENTEN

A.001 — 2026-04-07 — ULID: 01JWTFKN3GENESIS — CuiperStapNr: 42
  Initieel document aangemaakt. Alle secties TO.001 t/m TO.010 zijn eerste versie.
  Bron: bestaande code + conversatie-reconstructie stap 1-42.
