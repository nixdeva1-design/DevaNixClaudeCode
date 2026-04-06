# CuiperOerOntologie
# Onveranderlijke kern — de basis van alles
# Gesedimenteerd: 2026-04-05
# CuiperStapNr: 24
# ULID: 01JWQNB2K6P8RXWN4LD7HCBDS9T

## Principe

Alles wat bestaat is een CuiperEntiteit.
Mens, dier, plant, machine, mineraal, AI, software, code regel,
database, netwerk node, signaal — alles heeft dezelfde basis.

De ontologie definieert WAT kan bestaan, niet wat bestaat.
De CuiperCore ligt vast. De expressie evolueert.

## CuiperEntiteit — universele eigenschappen

```
ulid         → uniek punt in tijd en ruimte (Lexicographically Sortable)
nr           → positie in hive/topologie
naam         → identiteit
karakter     → aard, persoonlijkheid
archetype    → patroon waaruit het voortkomt
rol          → functie in het geheel
geschiedenis → alle vorige versies, nooit verwijderd
functie      → wat het doet
mandaat      → waarom het bestaat
verbindingen → relaties naar andere entiteiten
status       → actief | inactief | CAN | gepland | gearchiveerd
```

## CAN waarde

CAN = pure potentie. Ongelijk aan null. Ongelijk aan NaN.
Een CAN entiteit bestaat — maar is nog niet uitgedrukt.
Zoals Nul (CuiperHiveNr 0): aanwezig als ademruimte voor potentie.

## Cuip

Een Cuip is een CuiperEntiteit met CAN waarde.
Het staat TUSSEN elke twee regels software.
Het is een synaps — een latent verbindingspunt.

```
CuiperHeader [Cuip + ULID]     ← begin van elk bestand
  regel 1    [ULID tupel]
Cuip         [ULID, CAN]       ← stub, potentie, niet null
  regel 2    [ULID tupel]
Cuip         [ULID, CAN]
  regel 3    [ULID tupel]
```

De Cuip begint als stub. Wordt later ontwikkeld zonder
bestaande regels aan te raken. De verbindingen zijn al
opgeslagen in de database voor de Cuip actief wordt.

## Versioning principe

```
Versie n    → blijft bestaan, verbindingen bewaard
Versie n+1  → alleen geëvalueerde delta
Pointer     → huidige actieve versie
```

Nooit herschrijven. Alleen evalueren.
De oude versie blijft naast de nieuwe bestaan.
Verbindingen zijn opgeslagen — de topologie verandert niet,
alleen de inhoud van nodes evolueert.

## AST relatie

De AST legt de structuur vast — statisch ontwerp.
Runtime is dynamisch — entiteiten evalueren.
Delta tussen versies = alleen gewijzigde nodes.
Alle versies bewaard in database.

## Schaalniveaus

```
Macro:   netwerk topologie   → modules als nodes
Meso:    module topologie    → bestanden als nodes
Micro:   bestand topologie   → regels als nodes
Nano:    regel topologie     → tokens als nodes
Sub-nano: machine laag       → bytes, mnemonics, hex als nodes
```

## Machine Laag

Elke machine instructie is een CuiperEntiteit.
Elke hex byte is een potentiële Cuip.
De ontologie gaat tot op dit niveau.

```
CuiperMachineLaag
├── Assembler     NASM, FASM — mnemonics als entiteiten
├── C / C++       systeem laag, driver niveau
├── Fortran       numeriek, wetenschappelijk
├── Pascal        Free Pascal, Delphi compatibel
├── Hex           binaire inspectie, radare2
└── Rust          vervangt C op systeem niveau
```

Editor compatibiliteit:
Neovim en VSCodium delen dezelfde LSP servers.
Eén LSP server = één bron van waarheid voor beide editors.
Overstap tussen editors zonder configuratieverlies.

Elk niveau heeft dezelfde ontologie. Zelfgelijkend.

## GNN integratie

Neo4j graph → GNN training data
Het systeem leert van zijn eigen topologie.
Elektronisch biologisch mechanisme — evolueert maar kern ligt vast.
