# CuiperGenesis — Deel II: Functioneel Ontwerp
# Regelnummers zijn stabiele referenties. Nooit verwijderen. Alleen aanvullen via amendement.
# Aangemaakt: CuiperStapNr 42 — ULID: 01JWTFKN3GENESIS — 2026-04-07
#
# Dit document beschrijft WAT het systeem doet vanuit gebruikersperspectief.
# Het HOE staat in CuiperGenesis-technisch.md.

## FO.001 — Systeemoverzicht

FO.001.01  CuiperHive is een modulair AI/automatiserings-platform op NixOS.
FO.001.02  Het systeem bestaat uit losse, verwisselbare modules.
FO.001.03  Elke module is standaard uitgeschakeld (enable = false).
FO.001.04  Een klantprofiel zet de benodigde modules aan.
FO.001.05  Nieuw klantprofiel = één .nix bestand + één regel in flake.nix.
FO.001.06  Deploy: nixos-rebuild switch --flake .#<klantprofiel>
FO.001.07
FO.001.08  Het systeem is bedoeld voor:
FO.001.09    — AI-experimenten via Ollama, n8n, LangChain
FO.001.10    — Data-verwerking via PostgreSQL, DuckDB, Neo4j, MongoDB
FO.001.11    — Signaal-routing via Zenoh bus
FO.001.12    — Inferentie via MindsDB, MLflow, Datalog/Prolog in Rust
FO.001.13    — Observability via Jaeger distributed tracing

## FO.002 — De Werkbank

FO.002.01  De werkbank is de primaire toolset van Cuiper.
FO.002.02  Alle andere componenten dienen de werkbank.
FO.002.03
FO.002.04  Werkbank component 1: Ollama
FO.002.05    Lokale LLM inferentie. Geen externe API nodig.
FO.002.06    Modellen draaien on-premise. Data verlaat de machine niet.
FO.002.07    Koppelt aan n8n via HTTP API (poort 11434).
FO.002.08
FO.002.09  Werkbank component 2: n8n
FO.002.10    Workflow automatisering. Visuele flow-builder.
FO.002.11    Koppelt Ollama, Zenoh, databases, en externe services.
FO.002.12    Elke workflow is een CuiperEntiteit met ULID en trail log.
FO.002.13
FO.002.14  Werkbank component 3: LangChain
FO.002.15    Orchestratie van LLM-ketens. Retrieval-augmented generation.
FO.002.16    Koppelt aan pgvector voor vector similarity search.
FO.002.17    Koppelt aan Neo4j voor graph-gebaseerde kennisrepresentatie.

## FO.003 — Klantprofielen

FO.003.01  Een klantprofiel is een NixOS configuratie die specifieke modules activeert.
FO.003.02  Drie standaard profielen:
FO.003.03
FO.003.04  Profiel 1: standaard
FO.003.05    Basis werkplek. PostgreSQL, Nginx, SSH.
FO.003.06    Geschikt voor: ontwikkelomgeving zonder zware AI-tools.
FO.003.07    Bestand: nixos/clients/standaard.nix
FO.003.08
FO.003.09  Profiel 2: ai-werkstation
FO.003.10    Volledig AI-platform. Alle werkbank-tools actief.
FO.003.11    PostgreSQL + pgvector, Neo4j, MongoDB, DuckDB.
FO.003.12    Ollama, n8n, MindsDB, MLflow, Jaeger.
FO.003.13    Bestand: nixos/clients/ai-werkstation.nix
FO.003.14
FO.003.15  Profiel 3: minimal
FO.003.16    Alleen basis NixOS. Geen services. Geen databases.
FO.003.17    Geschikt voor: clean-room installatie of USB boot.
FO.003.18    Bestand: nixos/clients/minimal.nix
FO.003.19
FO.003.20  Nieuw profiel toevoegen:
FO.003.21    1. Maak nixos/clients/<naam>.nix aan
FO.003.22    2. Definieer welke cuiper.services.*.enable = true
FO.003.23    3. Voeg toe aan nixos/flake.nix: <naam> = mkCuiperSystem ./clients/<naam>.nix
FO.003.24    4. Deploy: nixos-rebuild switch --flake .#<naam>

## FO.004 — Namespace Isolatie

FO.004.01  Elk onderdeel van het systeem opereert in een namespace.
FO.004.02  Namespaces zijn strikt geïsoleerd. Cross-namespace communicatie vereist een brug.
FO.004.03
FO.004.04  klant/**   — klantdata. Geïsoleerd per klant.
FO.004.05  lab/**     — experimenten. Mogen niet in productie lekken.
FO.004.06  airgap/**  — geen externe verbinding toegestaan. Fysieke isolatie.
FO.004.07  agi/**     — ML/AI experimenten. Strikt gescheiden van klantdata.
FO.004.08
FO.004.09  De cuiper-router crate handhaaft deze isolatie.
FO.004.10  Een signaal van lab/** naar klant/** zonder expliciete CuiperNaamspaceBrug
FO.004.11  resulteert in CuiperRouterFout::NamespaceSchending.
FO.004.12  Deze fout wordt gelogd. Nooit stil weggegooid.

## FO.005 — Backlog en Taakbeheer

FO.005.01  Het systeem beheert zijn eigen takenlijst via CuiperBacklogPlanner.sh.
FO.005.02  Elke taak heeft: ID, Status, Prioriteit, Omschrijving, StapNr, ULID.
FO.005.03
FO.005.04  Status waarden:
FO.005.05    OPEN        — taak is gedefinieerd, nog niet gestart
FO.005.06    BEZIG       — taak is actief in uitvoering
FO.005.07    KLAAR       — taak is voltooid en gesedimenteerd
FO.005.08    GEBLOKKEERD — taak wacht op externe factor
FO.005.09    GESEDIMENTEERD — taak is archief, nooit verwijderd
FO.005.10
FO.005.11  Prioriteit waarden: KRITIEK | HOOG | MEDIUM | LAAG
FO.005.12
FO.005.13  Wet: niets in de backlog wordt verwijderd.
FO.005.14  KLAAR items zakken naar het einde van de lijst.
FO.005.15  De backlog is een sedimentatielog van alle taken ooit gedefinieerd.
FO.005.16
FO.005.17  ClaudeCode heeft continu mandaat als CuiperBacklogOperator:
FO.005.18    — Status en prioriteit wijzigen zonder opdracht van Cuiper
FO.005.19    — Foute statussen corrigeren (CuiperBacklogOpschoener)
FO.005.20    — Items toevoegen als nieuwe taken ontdekt worden

## FO.006 — Trail Logging

FO.006.01  Elke actie van ClaudeCode wordt gelogd naar logs/trail/.
FO.006.02  Elke trail log heeft het volgende formaat:
FO.006.03
FO.006.04    ULID:                  <ulid>
FO.006.05    UnixTimestamp:         <unix>
FO.006.06    CuiperStapNr:          <n>
FO.006.07    Met:                   CuiperHiveNr <nr> — <naam>
FO.006.08    Hive:                  <branch>
FO.006.09    Vraagprompt:           <de exacte vraag van Cuiper/Deva>
FO.006.10    Redenering:            <waarom deze aanpak gekozen>
FO.006.11    Antwoordprompt:        <samenvatting van wat gedaan is>
FO.006.12    Plan:                  <wat de volgende stap is>
FO.006.13    CuiperStatusBackup{n}: <staat vóór actie>
FO.006.14    CuiperVerwachtBackup:  <verwachte staat na actie>
FO.006.15    Rollbackpunt:          <git commit hash>
FO.006.16    CuiperNaVerwacht:      <werkelijke staat na actie>
FO.006.17
FO.006.18  Trail logs worden na elke respons gecommit en gepusht.
FO.006.19  Een trail log die niet gepusht is, bestaat niet.

## FO.007 — Prompt Export

FO.007.01  Alle vraagprompts worden geëxporteerd naar logs/prompts/ als JSON en JSONL.
FO.007.02  Formaat per record:
FO.007.03
FO.007.04    {
FO.007.05      "sessie":         "<uuid>",
FO.007.06      "timestamp":      "<ISO 8601>",
FO.007.07      "cuiper_stap_nr": <n>,
FO.007.08      "rol":            "human" | "assistant",
FO.007.09      "tekst":          "<inhoud>",
FO.007.10      "bron":           "session-jsonl" | "session-live" | "conversation-summary",
FO.007.11      "is_summary":     true | false
FO.007.12    }
FO.007.13
FO.007.14  Probleem: Claude Code compacteert sessies bij context-limiet.
FO.007.15  Na compaction zijn individuele messages niet meer extracteerbaar.
FO.007.16  Oplossing: CuiperPromptExporter.sh exporteert elke sessie direct.
FO.007.17  Bij reconstructie: gebruik conversation-summary als bron.

## FO.008 — KlaarMelding Protocol

FO.008.01  Elke respons van ClaudeCode eindigt met een CuiperKlaarMelding.
FO.008.02  De KlaarMelding toont:
FO.008.03
FO.008.04    — CuiperStapNr + ULID + commit hash + branch
FO.008.05    — Sessie prompt teller + context drempel status
FO.008.06    — Backlog samenvatting: KRITIEK/HOOG/MEDIUM/LAAG counts
FO.008.07    — Commando's voor prioriteit en status wijzigen
FO.008.08
FO.008.09  De context drempel is dynamisch. Nooit een vaste waarde.
FO.008.10  Algoritme:
FO.008.11    avg = gemiddelde van logs/trail/prompt_session_history.txt
FO.008.12    drempel_zacht = avg * 0.80  → waarschuw
FO.008.13    drempel_hard  = avg * 0.95  → blokkeer, forceer sessie-afsluitplan
FO.008.14
FO.008.15  Elke sessie die eindigt voegt zijn stapnr toe aan de history.
FO.008.16  De drempel wordt na elke sessie herberekend. Het systeem leert.

## FO.009 — USB Boot en NixOS Installatie

FO.009.01  Dit is het originele doel van branch claude/linux-usb-dual-boot-Hsk67.
FO.009.02  Backlog item 01JWQN09 — HOOG — nog OPEN.
FO.009.03
FO.009.04  Doel: NixOS installeren op USB zodat het zelfstandig opstart naast Windows 10.
FO.009.05  Methode: Ventoy met GRUB2 modus, NixOS ISO als boot optie.
FO.009.06
FO.009.07  Stap 1 (KLAAR): Ventoy geïnstalleerd op USB.
FO.009.08  Stap 2 (KLAAR): Ubuntu + Kali ISO's geladen via Ventoy.
FO.009.09  Stap 3 (OPEN):  NixOS installatie configureren vanuit het minimal profiel.
FO.009.10  Stap 4 (OPEN):  CuiperHive flake op USB installeren.
FO.009.11  Stap 5 (OPEN):  Dual boot verificatie: Windows 10 ongeraakt.
FO.009.12
FO.009.13  Risico: Windows bootloader mag niet overschreven worden.
FO.009.14  Mitigatie: NixOS GRUB installeert op USB device, niet op interne schijf.
FO.009.15  Verificatie: Windows 10 start normaal op zonder USB.

---
## AMENDEMENTEN

A.001 — 2026-04-07 — ULID: 01JWTFKN3GENESIS — CuiperStapNr: 42
  Initieel document aangemaakt. Alle secties FO.001 t/m FO.009 zijn eerste versie.
  Bron: conversatie-reconstructie + bestaande code in repository.
