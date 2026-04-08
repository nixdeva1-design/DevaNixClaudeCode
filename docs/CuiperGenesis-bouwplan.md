# CuiperGenesis — Deel IV: Bouwplan
# Regelnummers zijn stabiele referenties. Nooit verwijderen. Alleen aanvullen via amendement.
# Aangemaakt: CuiperStapNr 42 — ULID: 01JWTFKN3GENESIS — 2026-04-07
#
# Dit document beschrijft de VOLGORDE van bouwen.
# Elk item heeft: regelnr, status, afhankelijkheden, verificatie.

## BP.001 — Bouwprincipes

BP.001.01  Bouw van basis naar complex. Nooit andersom.
BP.001.02  Een component mag pas gebouwd worden als al zijn afhankelijkheden KLAAR zijn.
BP.001.03  Elke bouwstap volgt de cyclus:
BP.001.04    ontwerpen → documenteren → wegschrijven → plannen → wegschrijven →
BP.001.05    bouwen → wegschrijven → controleren → wegschrijven
BP.001.06
BP.001.07  Elke wegschrijven = commit + push. Nooit lokaal laten staan.
BP.001.08  Een bouwstap die niet gepusht is, bestaat niet.
BP.001.09
BP.001.10  Bij mislukking: rollback naar laatste stabiele A.
BP.001.11  Analyseer het verschil C-B. Sedimenteer de analyse in trail log.
BP.001.12  Herhaal met gecorrigeerd plan B'.

## BP.002 — Fundament (KLAAR)

BP.002.01  [KLAAR] Stap 01 — Git repository aanmaken
BP.002.02    Verificatie: git log --oneline -1 toont commit
BP.002.03
BP.002.04  [KLAAR] Stap 02 — CuiperConfig.env
BP.002.05    Geen hardcoded paden. Alle scripts sourcen dit.
BP.002.06    Verificatie: source CuiperConfig.env && echo $CUIPER_REPO
BP.002.07
BP.002.08  [KLAAR] Stap 03 — CLAUDE.md protocol
BP.002.09    Protocol geladen bij elke sessie.
BP.002.10    Verificatie: aanwezig in repo root
BP.002.11
BP.002.12  [KLAAR] Stap 04 — Stop hook (.claude/settings.json)
BP.002.13    CuiperPromptCounter.sh triggert na elke respons.
BP.002.14    Verificatie: cat .claude/settings.json | grep Stop

## BP.003 — Protocol Scripts (KLAAR)

BP.003.01  [KLAAR] Stap 10 — CuiperBacklogPlanner.sh
BP.003.02    Afhankelijk van: CuiperConfig.env
BP.003.03    Verificatie: bash CuiperBacklogPlanner.sh samenvatting
BP.003.04
BP.003.05  [KLAAR] Stap 11 — CuiperPromptCounter.sh
BP.003.06    Afhankelijk van: CuiperConfig.env, CuiperJaegerSpan.sh
BP.003.07    Verificatie: counter file aanwezig in logs/trail/
BP.003.08
BP.003.09  [KLAAR] Stap 12 — CuiperKlaarMelding.sh
BP.003.10    Afhankelijk van: CuiperBacklogPlanner.sh, CuiperConfig.env
BP.003.11    Verificatie: bash CuiperKlaarMelding.sh TEST 0 toont output
BP.003.12
BP.003.13  [KLAAR] Stap 13 — CuiperListener.sh
BP.003.14    Afhankelijk van: CuiperJaegerSpan.sh, CuiperConfig.env
BP.003.15    Verificatie: bash CuiperListener.sh --exec "echo test" --naam test --stap 0
BP.003.16
BP.003.17  [KLAAR] Stap 14 — CuiperJaegerSpan.sh
BP.003.18    Afhankelijk van: CuiperConfig.env, Jaeger (optioneel)
BP.003.19    Verificatie: script bestaat, bij geen Jaeger: logt fout naar trail, gaat door
BP.003.20
BP.003.21  [KLAAR] Stap 15 — CuiperPromptExporter.sh
BP.003.22    Afhankelijk van: CuiperConfig.env, Python3
BP.003.23    Verificatie: bash CuiperPromptExporter.sh --sessie <uuid>

## BP.004 — NixOS Modules (KLAAR)

BP.004.01  [KLAAR] Stap 20 — CuiperPorts.nix
BP.004.02    Geen afhankelijkheden. Altijd geladen.
BP.004.03    Verificatie: alle poorten aanwezig als config.cuiper.ports.*
BP.004.04
BP.004.05  [KLAAR] Stap 21 — CuiperSystem.nix
BP.004.06    Afhankelijk van: CuiperPorts.nix
BP.004.07    Verificatie: bootloader, locale, users geconfigureerd
BP.004.08
BP.004.09  [KLAAR] Stap 22 — CuiperServices.nix
BP.004.10    Afhankelijk van: CuiperPorts.nix
BP.004.11    Alle services enable = false standaard
BP.004.12    Verificatie: nix eval .#nixosConfigurations.minimal.config.cuiper.services
BP.004.13
BP.004.14  [KLAAR] Stap 23 — CuiperDatabases.nix
BP.004.15    Afhankelijk van: CuiperPorts.nix
BP.004.16    Verificatie: postgresql, neo4j, mongodb opties aanwezig
BP.004.17
BP.004.18  [KLAAR] Stap 24 — CuiperNginx.nix
BP.004.19    Afhankelijk van: CuiperPorts.nix, CuiperServices.nix
BP.004.20    Vhosts alleen actief als bijbehorende service enabled is
BP.004.21    Verificatie: vhost voor Gitea bestaat als gitea.enable = true
BP.004.22
BP.004.23  [KLAAR] Stap 25 — CuiperJaeger.nix
BP.004.24    Afhankelijk van: CuiperPorts.nix
BP.004.25    Verificatie: systemctl status jaeger (als enabled)
BP.004.26
BP.004.27  [KLAAR] Stap 26 — flake.nix + mkCuiperSystem + klantprofielen
BP.004.28    Afhankelijk van: alle modules
BP.004.29    Verificatie: nix flake check .

## BP.005 — Rust Crates (KLAAR)

BP.005.01  [KLAAR] Stap 30 — cuiper-core
BP.005.02    Geen workspace-afhankelijkheden
BP.005.03    Modules: donut, cuip, bewaker, entiteit, hive, mandaat, markov
BP.005.04    Tests: 26 (inclusief 10 donut_tests)
BP.005.05    Verificatie: cargo test -p cuiper-core → 26 passed
BP.005.06
BP.005.07  [KLAAR] Stap 31 — cuiper-bus
BP.005.08    Afhankelijk van: cuiper-core
BP.005.09    Types: CuiperSignaal, namespace traits
BP.005.10    Verificatie: cargo build -p cuiper-bus
BP.005.11
BP.005.12  [KLAAR] Stap 32 — cuiper-datalog
BP.005.13    Afhankelijk van: cuiper-core
BP.005.14    Engine: forward-chaining, vaste punt detectie
BP.005.15    Tests: transitieve relaties, geen duplicaten, inferentie
BP.005.16    Verificatie: cargo test -p cuiper-datalog
BP.005.17
BP.005.18  [KLAAR] Stap 33 — cuiper-router
BP.005.19    Afhankelijk van: cuiper-core, cuiper-bus
BP.005.20    Tests: 15 (routeregel, brug, router)
BP.005.21    Bugfix: past_op() /* patroon prefix -1 i.p.v. -2
BP.005.22    Verificatie: cargo test -p cuiper-router → 15 passed

## BP.006 — Ontologie (KLAAR)

BP.006.01  [KLAAR] Stap 34 — CuiperHiveCoreOntologie.sql
BP.006.02    Afhankelijk van: PostgreSQL (CuiperDatabases.nix)
BP.006.03    Tabellen: cuiper_hive_lid, cuiper_hive_component, cuiper_hive_verbinding,
BP.006.04               cuiper_listener_trace
BP.006.05    Kolom erft_van: keten van Cuiper → CuiperCore → CuiperDonut → component
BP.006.06    Verificatie: psql -c "SELECT COUNT(*) FROM cuiper_hive_component" → 25

## BP.007 — Documentatie (KLAAR stap 42)

BP.007.01  [KLAAR] Stap 42 — CuiperGenesis documenten
BP.007.02    Deel I: docs/CuiperGenesis-filosofie.md   (F.001-F.010)
BP.007.03    Deel II: docs/CuiperGenesis-functioneel.md (FO.001-FO.009)
BP.007.04    Deel III: docs/CuiperGenesis-technisch.md  (TO.001-TO.010)
BP.007.05    Deel IV: docs/CuiperGenesis-bouwplan.md    (BP.001-BP.009) ← dit bestand
BP.007.06    Verificatie: alle 4 bestanden aanwezig in docs/

## BP.008 — Open Items (OPEN)

BP.008.01  [OPEN] Stap 50 — NixOS USB Installatie (01JWQN09)
BP.008.02    Afhankelijk van: minimal profiel (KLAAR), Ventoy USB (KLAAR)
BP.008.03    Plan:
BP.008.04      a. Boot van Ubuntu Live USB
BP.008.05      b. Partitioneer USB: EFI + NixOS root (btrfs)
BP.008.06      c. nixos-install --flake .#minimal
BP.008.07      d. Verificeer: Windows 10 start zonder USB
BP.008.08      e. Verificeer: NixOS start met USB
BP.008.09    Risico: GRUB overschrijft Windows bootloader
BP.008.10    Mitigatie: installeer GRUB op USB device (/dev/sdX), niet op /dev/sda
BP.008.11
BP.008.12  [OPEN] Stap 51 — CuiperHiveCoreOntologie laden bij PostgreSQL boot (01KNJCNGA)
BP.008.13    Afhankelijk van: CuiperDatabases.nix (KLAAR)
BP.008.14    Plan: PostgreSQL initialScript in NixOS laadt SQL bij eerste start
BP.008.15    Verificatie: SELECT COUNT(*) FROM cuiper_hive_lid → 5
BP.008.16
BP.008.17  [OPEN] Stap 52 — CuiperHeader in alle code bestanden (01JWQN06 + 01KNJCNH5)
BP.008.18    Doel: elk bestand begint met CuiperHeader comment:
BP.008.19      # Erft van: CuiperCore → CuiperDonut → <component>
BP.008.20      # ULID: <component-ulid>
BP.008.21      # CuiperStapNr aangemaakt: <n>
BP.008.22    Scope: alle .sh, .rs, .nix, .sql bestanden
BP.008.23
BP.008.24  [OPEN] Stap 53 — Jaeger UI vhost in CuiperNginx (01KNJCNGH)
BP.008.25    Afhankelijk van: CuiperNginx.nix, CuiperJaeger.nix
BP.008.26    Plan: vhost jaeger.<domein> → localhost:16686
BP.008.27
BP.008.28  [OPEN] Stap 54 — n8n + Ollama workflow template (01KNJCNGY)
BP.008.29    Afhankelijk van: CuiperServices.nix (n8n + Ollama)
BP.008.30    Plan: n8n workflow JSON exporteren als template in repo
BP.008.31
BP.008.32  [OPEN] Stap 55 — API Gateway (01JWQN05)
BP.008.33    CuiperApiGateway.nix: reverse proxy met auth voor alle services
BP.008.34
BP.008.35  [OPEN] Stap 56 — GNN Pipeline (01JWQN08)
BP.008.36    Neo4j → training data export → GNN model training
BP.008.37
BP.008.38  [OPEN] Stap 57 — namespace-guard Rust crate (01JWQN17)
BP.008.39    Compile-time namespace isolatie via Rust type system

## BP.009 — Verificatie van het Geheel

BP.009.01  Het systeem is correct gebouwd als alle volgende checks slagen:
BP.009.02
BP.009.03  CHECK-001: cargo test --workspace → 0 failures
BP.009.04  CHECK-002: nix flake check .     → no errors
BP.009.05  CHECK-003: bash scripts/protocol/CuiperKlaarMelding.sh TEST 0 → output zichtbaar
BP.009.06  CHECK-004: git log --oneline -5  → 5 recente commits zichtbaar
BP.009.07  CHECK-005: ls logs/trail/        → trail logs aanwezig
BP.009.08  CHECK-006: ls logs/prompts/      → prompt export aanwezig
BP.009.09  CHECK-007: ls docs/CuiperGenesis-*.md → 4 genesis documenten
BP.009.10  CHECK-008: cat backlog/CuiperBacklog.md | grep OPEN → open items zichtbaar
BP.009.11
BP.009.12  Als alle checks slagen: het systeem is in stabiele staat A.
BP.009.13  Elke volgende bouwstap begint met: alle checks opnieuw uitvoeren.

---
## AMENDEMENTEN

A.001 — 2026-04-07 — ULID: 01JWTFKN3GENESIS — CuiperStapNr: 42
  Initieel document aangemaakt. Alle secties BP.001 t/m BP.009 zijn eerste versie.
  BP.002-BP.007 beschrijven KLAAR items stap 1-42.
  BP.008 beschrijft OPEN items met expliciete afhankelijkheden en plannen.
