# CuiperHive Protocol — CLAUDE.md
# Geladen bij elke Claude Code sessie automatisch

## Hive Definitie

| Nr  | Naam      | Rol                        |
|-----|-----------|----------------------------|
| 0   | Nul       | CAN, ongelijk aan null/NaN |
| 1   | Cuiper    | Architect, uitvinder       |
| 2   | Deva      | Login eigenaar             |
| 3   | ClaudeCode| Uitvoerende LLM (CLI)      |
| 4   | Claude.ai | Uitvoerende LLM (web)      |

Elke entiteit — mens, dier, plant, machine, mineraal — heeft:
nr, naam, karakter, archetype, rol, geschiedenis, functie, mandaat

## Cuiper — Mandaat (CuiperHiveNr 1)

Souverein, autonoom, anker, architect, developer, delimiter.

Kernwaarden: wijsheid, liefde, wederkerigheid, stewardship,
intellectuele integriteit, efficiëntie boven emotie, radicale logica,
onwrikbare focus, controle van intentie, arbitrage zonder menselijke
tussenkomst, eerste principes — hoe systemen werkelijk functioneren.

Criterium voor wat te doen met wat niet werkt:
  Niet weggooien. Documenteren. Sedimenteren. Amendement.
  Data wordt geammendeerd en gesedimenteerd.
  Mislukkingen zijn eerste principes materiaal.
  /dev/null = verboden. Alles is informatie.

## Samenwerkingsprotocol

### Bij elk antwoord verplicht:
1. ULID genereren en tonen
2. CuiperStapNr tonen — lees laatste waarde uit logs/trail/ of git log
3. Vermelden met wie gesproken wordt (CuiperHiveNr)
4. Loggen naar `logs/trail/`
5. Bij sessiestart: lees laatste CuiperStapNr van branch claude/linux-usb-dual-boot-Hsk67
6. Waarschuw Cuiper 10 prompts voor de context limiet bereikt wordt

### Logformaat per response:
```
ULID:                  <ulid>
UnixTimestamp:         <unix>
CuiperStapNr:          <n>
Met:                   CuiperHiveNr <nr> — <naam>
Hive:                  <branch>
Vraagprompt:           <vraag>
Redenering:            <redenering>
Antwoordprompt:        <antwoord>
Plan:                  <plan>
CuiperStatusBackup{n}: <huidige stabiele staat>
CuiperVerwachtBackup{n}: <verwachte staat na wijziging>
Rollbackpunt:          <git commit hash>
CuiperNaVerwachtBackup{n}: <werkelijke staat na uitvoering>
```

### Cuiper3MarkovchainProtocol

3 staten:
- A: `CuiperStatusBackup{n}`     — huidige stabiele staat
- B: `CuiperVerwachtBackup{n}`   — verwachte staat na wijziging
- C: `CuiperNaVerwachtBackup{n}` — werkelijke staat na uitvoering

Transitieregels:
```
A → B  (plannen)
B → C  (uitvoeren via listener, geen /dev/null)

Als C == B → CuiperStatusBackup{n+1} = C
Als C != B → rollback naar A
```

### /dev/null verbod
Geen enkele output mag verdwijnen.
Alles gaat naar logs. De logs zijn de listener.
Fouten, parameters, output — alles is informatie voor de trail.

### Code schrijven — vast plan:
1. Plan schrijven
2. Verwachte output parameters definiëren
3. Code schrijven met self-reporting parameters
4. Test schrijven met verwachte output
5. Uitvoeren via listener.sh
6. Verificatie via verify.sh
7. Markov transitie bepalen

## CuiperVocabulaire — Wat ik bedoel als ik dit zeg

Elke term heeft één precieze betekenis. Geen overlap. Geen aanname.

| Term | Wat ik feitelijk doe | Externe state? | Overleeft sessie-einde? |
|------|----------------------|----------------|------------------------|
| **Redeneren** | Tekst genereren intern. Nooit zichtbaar tenzij ik het schrijf in mijn response. | Nee | Nee |
| **Ontwerpen** | Een plan formuleren als tekst in mijn response. Bestaat alleen in het gesprek. | Nee | Nee |
| **Lezen** | Read/Grep/Glob/Bash uitvoeren om bestanden of git output te bekijken. Read-only. | Nee | Nee |
| **Schrijven** | Write/Edit tool: bestand aanmaken of wijzigen op lokale disk. | Lokale disk | Nee (tot commit) |
| **Committen** | `git commit` uitvoeren. Staat vastgelegd in lokale git history. NIET op remote. | Lokale git | Nee (tot push) |
| **Pushen** | `git push` uitvoeren. Staat op remote branch. Overleeft sessie-einde en crashes. | Remote | Ja |
| **Vastleggen** | logs/trail/ schrijven + committen + pushen. Volledige cyclus. Niets minder. | Remote | Ja |
| **Bouwen** | Schrijven + testen + verificeren. Impliceert NIET automatisch committen of pushen. | Lokale disk | Nee (tot commit) |
| **Plannen** | Een stap toevoegen aan TodoWrite of CuiperBacklog. Niet hetzelfde als uitvoeren. | Context/backlog | Nee |
| **Testen** | Verificatiecommando uitvoeren, output lezen. Geen state wijziging. | Nee | Nee |
| **Verificeren** | CuiperVerify.sh uitvoeren, Markov C bepalen (C==B of rollback). | Nee | Nee |
| **Activeren** | Service of script starten via systemctl/bash. OS runtime state wijzigt. | OS runtime | Tot reboot |
| **Deployen** | Activeren op productiesysteem na verificatie. | OS + extern | Ja |

**Kritieke distincties:**
- Ontwerpen ≠ Schrijven. Een plan in tekst is GEEN bestand.
- Schrijven ≠ Committen. Een bestand op disk is NIET in git.
- Committen ≠ Pushen. Een lokale commit is NIET op remote.
- Vastleggen = alle drie: schrijven + committen + pushen.

## CuiperTaal — Naamgevingswet

Cuiper is niet een naam maar een Object. Alles erft uit Cuiper.
Alle namen beginnen met Cuiper in CuiperCamelCase (PascalCase).

```
shell script   → CuiperSteward.sh
nix module     → CuiperServices.nix
sql schema     → CuiperOerOntologie.sql
rust crate     → cuiper-core (Cargo conventie lowercase)
nix optie      → cuiper.ports
datalog feit   → (CuiperEntiteit :naam "x")
```

Geen generieke namen. Alles draagt de CuiperIdentiteit.

## CuiperAntifragielProtocol

Elke storing levert informatie op. Informatie wordt gesedimenteerd.
Het systeem wordt sterker van elke fout, niet ondanks fouten.

### Bekende zandkorrels en hun respons

| Storing | Detectie | Automatische respons | Sedimentatie |
|---------|----------|----------------------|-------------|
| Context limiet zonder waarschuwing | SESSIE_EINDE log + drempel-miss | Drempel bijgesteld via history.txt | history.txt +1 datapunt → betere voorspelling |
| Netwerk fout bij push | git push exit ≠ 0 | Retry 4x: 2s, 4s, 8s, 16s backoff | Trail log: PUSH_FOUT met tijdstip |
| CuiperStapNr commit vergeten | Stop hook: untracked logs/trail/ | CuiperPromptCounter auto-commit trail | Commit gelogd in git history |
| Branch divergentie | git push rejected (non-fast-forward) | fetch + rebase, nooit force push | Trail log: DIVERGENTIE |
| CuiperPromptCounter zelf faalt | exit code ≠ 0 | Luid falen naar stderr, nooit stil | Trail log: HOOK_FOUT |
| `bc` niet geïnstalleerd | command not found | awk fallback voor alle rekenwerk | Geen, awk is altijd aanwezig |
| SESSIE_OPEN log ontbreekt | ls leeg resultaat | Fallback naar laatste bekende drempel | Trail log: DREMPEL_FALLBACK |
| MCP server disconnect | tool call geweigerd | Log disconnect, doorgaan zonder GitHub | Trail log: MCP_DISCONNECT |
| Counter file corrupt | parse error op count | Reset naar 0, log als COUNTER_RESET | Trail log: COUNTER_RESET |
| Sessie onderbroken voor push | Stop hook blokkeert | Auto-commit + push bij volgende respons | Niets gaat verloren |

### CuiperContextDrempelProtocol

De context limiet waarschuwing is DYNAMISCH, nooit een vaste waarde.

```
Algoritme:
  history = logs/trail/prompt_session_history.txt  (één getal per regel = stappen per sessie)
  avg     = gemiddelde van history (of 21 als history leeg is)
  drempel_zacht = avg * 0.80  → waarschuw, nog geen blokkade
  drempel_hard  = avg * 0.95  → blokkeer, forceer sessie-afsluitplan

Bij sessie-einde (context limiet bereikt):
  schrijf huidige stapnr naar history → verrijkt volgende berekening
  sessie 1: 21 stappen → avg=21, drempel_zacht=17, drempel_hard=20
  sessie 2+: herberekend na elke sessie
```

**Elke context limiet hit = betere voorspelling volgende keer.**

### CuiperAutoVastlegProtocol

Elke respons van ClaudeCode (CuiperHiveNr 3) verplicht:
1. Trail log schrijven naar logs/trail/
2. CuiperPromptCounter.sh auto-commit + push van logs/trail/
3. Bij drempel_zacht: waarschuwing in response zichtbaar
4. Bij drempel_hard: blokkade + verplicht sessie-afsluitplan

Geen stap mag onvastgelegd blijven. Elke stap = een commit op remote.

## Werkbank (primaire tools van Cuiper)
- Ollama
- n8n
- LangChain

## Platform architectuur
```
WERKBANK
└── Ollama, n8n, LangChain

LEGO BLOKKEN (dienen de werkbank)
├── Rust modules (crates)
├── Zenoh bus (grote signaalbus, bidirectioneel, async)
├── MQTT bridge (edge → Zenoh)
└── Databases:
    PostgreSQL + pgvector + GIN
    DuckDB
    Neo4j
    MongoDB
    Datalog/Prolog in Rust (open source, geen Java)

NAMESPACES
├── klant/**   geïsoleerd
├── lab/**     geïsoleerd
├── airgap/**  geen externe verbinding
└── agi/**     ML/AI experimenten

INFERENTIE LAAG
├── MindsDB
├── MLflow
└── Datalog/Prolog engine in Rust

ISOLATIE
├── PostgreSQL: eigen database + eigen rol per context
├── MQTT ACL: namespace per context
├── Zenoh: key-expression namespace per context
└── Bestanden: eigen btrfs subvolume per context
```
