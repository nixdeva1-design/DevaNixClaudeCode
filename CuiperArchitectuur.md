# Cuiper Architectuur — Gesprek 2026-04-07

## Context

Dit document bevat de kernconcepten zoals gedicteerd door de architect in een gesprek met Claude Code op 7 april 2026. Het is een levend document — de basis voor verdere uitwerking.

---

## De Architect

- AI scientist / analist / systeem architect / database developer
- Bouwt een kantoor op verwisselbare USB
- Werkt met personeel én AI als gelijkwaardige actoren
- Vroegere connectie met Lambert Meertens (ABC taal, CWI)
- Anti-cartesiaans: zoekt de outlier, niet het gemiddelde
- Python-ideeen zijn eerder gedicteerd als kind, Guido van Rossum heeft dit niet volledig begrepen — de Von Neumann grens is nooit omzeild via normalisering

---

## De Drie Sporen

Alle ontwikkeling loopt parallel in drie sporen:

| Spoor | Beschrijving |
|-------|-------------|
| **Normaal** | Standaard manier (relationeel, cartesiaans) |
| **Cuiper** | De eigen manier — anti-normalisering, outlier-gericht |
| **AI** | De AI-manier — vectoren, multi-model |

---

## Mechanische Biologie

Alles erft van **Cuiper**. Net als in biologie elke cel DNA draagt, draagt elke module een Cuip-structuur. Het systeem is organisch maar mechanisch gedetermineerd.

---

## De Cuip

### Definitie

Een **Cuip** is een eerste-klas object dat staat op de regel boven de coderegel die hij beheert. De Cuip en de regel eronder zijn onlosmakelijk verbonden. De Cuip *heerst* over precies die ene regel eronder.

### Structuur in code

```
-- CUIP:<ulid> MODULE:<module-ulid> NAAM:<modulenaam> REGEL:<n>
<coderegel die afgesloten wordt met ;>
-- CUIP:<ulid> MODULE:<module-ulid> NAAM:<modulenaam> REGEL:<n+1>
<volgende coderegel;>
```

- 1 Cuip per coderegel — altijd, geen uitzonderingen
- De coderegel eindigt altijd met `;`
- Na de `;` volgt direct de volgende Cuip
- Een coderegel is een **tupel** in de CuiperModule

### Wat de Cuip kent en beheert

De Cuip draagt als eigenschappen:
- Zijn eigen **ULID** (uniek, onveranderlijk)
- De **module ULID** van de module waar hij in zit
- De **modulenaam** (CuiperHeader)
- Het **huidige regelnummer** van de coderegel onder hem

### Regelnummer is dynamisch — ULID is permanent

Het regelnummer van de coderegel kan veranderen bij refactoring of wijziging van de module. Maar de **binding tussen Cuip ULID en code is permanent**. Bij elke wijziging wordt het regelnummer opnieuw toegewezen. De code zelf is een eigenschap van de Cuip — niet van de positie.

### Automatische Cuip bij nieuwe code

Elke nieuwe coderegel die geschreven wordt, krijgt **automatisch** een nieuwe Cuip boven zich geplaatst met een nieuwe distinct ULID.

---

## Cuip Minimale Configuratie

Elke Cuip is altijd tegelijk traceerbaar in minimaal drie systemen:

| Systeem | Rol |
|---------|-----|
| **PostgreSQL** | Relationele opslag, audit, mandaten |
| **Vectordatabase** | Semantische representatie van de Cuip |
| **GNN** (Graph Neural Network) | Relaties tussen Cuips, modules, systemen |

### Uitgebreide configuratie (contextafhankelijk)

Afhankelijk van hoe de Cuip op zijn specifieke plaats reageert op zijn omgeving, kan een Cuip ook verbonden zijn met:

- Meerdere grafen
- Aanvullende NN (Neural Networks)
- NixOS configuratie
- Datalog regels
- Logseq kennisgraaf

De Cuip beslist zelf (via zijn context) welke systemen actief zijn. De minimale config is altijd aanwezig.

---

## CAN — Potentie in plaats van Leegte

| Concept | Betekenis |
|---------|-----------|
| `NULL` | Er is niets — informatie vernietigd |
| `NaN` | Geen getal — onbepaald maar leeg |
| `CAN` | Potentie aanwezig — ruimte bestaat, waarde nog niet gerealiseerd |

CAN bewaart de outlier. NULL gooit hem weg. Een Cuip heeft nooit NULL of NaN — altijd CAN als er nog geen waarde is.

---

## De CuiperModule

### Harde grens

```
CuiperModule grootte: ≤ 100 regels (tupels)
```

Een CuiperModule is **nooit groter dan 100 regels**. Dit is een harde architectuurgrens, geen richtlijn. Alles wat groter is wordt gesplitst in meerdere modules.

### CuiperHeader

Elke module begint met een **CuiperHeader** die bevat:
- Module ULID
- Modulenaam
- Aantal regels / Cuips in de module
- Nummering van de regels

### Module klonen

Wanneer een module gekloond wordt:
- De **twin module** krijgt een **nieuwe module ULID**
- Alle Cuips in de twin module krijgen elk een **nieuwe distinct ULID**
- De regelnummers worden opnieuw toegewezen op basis van de huidige staat van de code
- De code zelf is overgenomen maar leeft nu als eigenschap van de nieuwe Cuip ULIDs

### Verwisselbaarheid

Modules zijn verwisselbaar. Als de CuiperHeader interface klopt, kan een module vervangen worden door een andere zonder dat het systeem de verbinding verliest — de Cuip ULIDs in andere databases blijven traceerbaar.

---

## Architectuurprincipes

1. **Anti-cartesiaans** — geen joins die de outlier wegmiddelen
2. **Soevereiniteit** — draait op USB, geen cloud-afhankelijkheid
3. **Leesbaar voor mens én machine** — altijd beide tegelijk
4. **Alles erft van Cuiper** — geen uitzonderingen
5. **Verwisselbaarheid** — modules zijn plug-and-play als de Cuip-interface klopt
6. **Potentie boven leegte** — CAN in plaats van Null
7. **Elke regel een Cuip** — geen coderegel zonder identiteit
8. **ULID is permanent, positie is dynamisch** — code hoort bij Cuip, niet bij regelnummer

---

## Huidige Repo Status (2026-04-07)

| Branch | Inhoud | Status |
|--------|--------|--------|
| `claude/research-claude-capabilities-4xRgL` | CuiperKantoor database schema (PostgreSQL, ULID, mandaten, GPS, processen) | PR #1 open |
| `claude/linux-usb-dual-boot-nUFrl` | Linux USB dual-boot scripts (+9660 regels) | Geen PR |
| `claude/linux-usb-dual-boot-Hsk67` | Linux USB dual-boot scripts (+9640 regels) | Duplicaat |
| `claude/github-mcp-pr-status-pAaUV` | Architectuurdocumentatie (deze sessie) | Actief |

---

## Volgende Stappen (intuïtief bepaald)

- [ ] Cuip formaat formaliseren als spec (syntax voor SQL, NixOS, Datalog, etc.)
- [ ] CuiperHeader structuur vastleggen als schema
- [ ] CAN type definiëren (PostgreSQL domain / type)
- [ ] GNN minimale config specificeren per Cuip
- [ ] Keuze maken tussen de twee USB branches
- [ ] PR #1 reviewen en beslissen over mergen
