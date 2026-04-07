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

Een **Cuip** is een eerste-klas object dat boven een coderegel staat en er onlosmakelijk mee verbonden is. De Cuip *heerst* over de regel eronder.

### Structuur

```
[CUIP: <ulid> | <vector> | <meta>]
<regel die afgesloten wordt met ;>
[CUIP: <ulid> | <vector> | <meta>]
<volgende regel;>
```

Elke regel heeft precies één Cuip erboven. De regel eindigt altijd met `;`. Daarna volgt de volgende Cuip.

### Eigenschappen

- **Eigen ULID** — elke Cuip is uniek identificeerbaar
- **Multi-database** — de Cuip ULID is gekoppeld aan meerdere databases tegelijk; dezelfde identiteit leeft in verschillende systemen
- **Nooit NaN of Null — maar CAN** — de waarde is nooit afwezig, alleen *potentieel*. CAN = er is ruimte en potentie, maar nog geen gerealiseerde waarde
- **Multi-vector** — de Cuip draagt tegelijk:
  - Een mensleesbare representatie
  - Een machineuitvoerbare representatie
  - Een AI-vectoriseerbare representatie
- **Heerst** — de Cuip bepaalt de context, identiteit en betekenis van de regel eronder

### CAN vs Null

| Concept | Betekenis |
|---------|-----------|
| `NULL` | Er is niets — informatie vernietigd |
| `NaN` | Geen getal — onbepaald maar leeg |
| `CAN` | Potentie aanwezig — ruimte bestaat, waarde nog niet gerealiseerd |

CAN bewaart de outlier. NULL gooit hem weg.

---

## De Module

### Regels

- Maximaal **~100 regels** per module
- Moet op een **A4** passen — cognitieve grens, niet technisch
- Alles wat niet op een A4 past is te complex: splitsen

### CuiperHeader

Elke module begint met een **CuiperHeader** die bevat:
- Moduleidentiteit (ULID)
- Aantal regels / Cuips
- Nummering van de regels
- Wat de module doet

### Genummerde regels

Elke regel in een module heeft een eigen nummer. De nummering is bekend in de CuiperHeader. Modules zijn verwisselbaar — als de interface (CuiperHeader) klopt, kan een module vervangen worden.

---

## Architectuurprincipes

1. **Anti-cartesiaans** — geen joins die de outlier wegmiddelen
2. **Soevereiniteit** — draait op USB, geen cloud-afhankelijkheid
3. **Leesbaar voor mens én machine** — altijd beide tegelijk
4. **Alles erft van Cuiper** — geen uitzonderingen
5. **Verwisselbaarheid** — modules zijn plug-and-play als de Cuip-interface klopt
6. **Potentie boven leegte** — CAN in plaats van Null

---

## Huidige Repo Status (2026-04-07)

| Branch | Inhoud | Status |
|--------|--------|--------|
| `claude/research-claude-capabilities-4xRgL` | CuiperKantoor database schema (PostgreSQL, ULID, mandaten, GPS, processen) | PR #1 open |
| `claude/linux-usb-dual-boot-nUFrl` | Linux USB dual-boot scripts (+9660 regels) | Geen PR |
| `claude/linux-usb-dual-boot-Hsk67` | Linux USB dual-boot scripts (+9640 regels) | Duplicaat |
| `claude/github-mcp-pr-status-pAaUV` | Huidige sessie | Leeg |

---

## Volgende Stappen (intuïtief bepaald)

- [ ] Cuip formaat formaliseren in een spec-bestand
- [ ] CuiperHeader structuur vastleggen
- [ ] CAN type definiëren (PostgreSQL domain / type)
- [ ] Keuze maken tussen de twee USB branches
- [ ] PR #1 reviewen en beslissen over mergen
