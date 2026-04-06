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
