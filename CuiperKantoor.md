# CuiperKantoor — Organisatie & Systeem Ontwerp

## Entiteiten en Mandaat Hiërarchie

```
Cuiper (1) — Volledig mandaat
    │
    └──► Deva (2) — Operationeel mandaat
              │
              ├──► Kantoorpersoneel — Tijdelijk mandaat (per proces)
              ├──► Klanten          — Tijdelijk mandaat (beperkt, per proces)
              ├──► ClaudeCode (3)   — Procesgebonden mandaat
              └──► Claude.ai (4)    — Procesgebonden mandaat
```

## Proces Parameters (kostenbewaking)

Elk proces draagt deze parameters mee — geen valuta, alleen metriek:

| Veld | Type | Formaat |
|------|------|---------|
| `process_ulid` | string | ULID |
| `start_unix` | integer | Unix timestamp (sec) |
| `end_unix` | integer | Unix timestamp (sec) |
| `tokens_used` | integer | Aantal tokens |

## Omgevingen

| Laag | Naam | Toegang | Data |
|------|------|---------|------|
| 1 | Ontwerp | Cuiper, design-agents | Geen productiedata |
| 2 | Test | Kantoorpersoneel, implementatie-agents | Testdata |
| 3 | Productie hoofd | Deva (mandaat vereist) | Productie |
| 3 | Productie sub (meerdere) | Deva | Productie |

## Infrastructuur

```
CuiperKantoor
├── Kantoor servers (on-premise, eigendom)
├── Cloud: Microsoft Azure (gehuurd)
├── Cloud: AWS Amazon (gehuurd)
├── Cloud: Google Cloud (gehuurd)
└── Klanten
    ├── Klant servers (eigendom klant)
    └── Klant laptops
```

## Agent Types

### Design-agent
- Rol: Co-ontwerper
- Levert: 2-3 opties met voor/nadelen, max 1 A4
- Schrijft geen code
- Stelt één verduidelijkingsvraag als nodig

### Implementatie-agent
- Rol: Bouwt goedgekeurde ontwerpen
- Vereiste: geclaimed GitHub issue met label `build`
- Branch: `agent/{machine-id}/{issue-nummer}`
- Maakt PR na voltooiing, koppelt aan issue

## Zichtbaarheid per rol

| Wie | Ziet |
|-----|------|
| Cuiper | Alles |
| Deva | Alle kosten, mandaten, systemen |
| Kantoorpersoneel | Eigen scope + mandaat |
| Klanten | Alleen eigen processen en mandaten |
| AI personeel | Alleen huidige taak + mandaat scope |

## Mandaat besluit structuur

```json
{
  "mandaat_ulid": "<ULID>",
  "van": "Deva",
  "namens": "Cuiper",
  "naar_type": "klant | persoon | ai_personeel",
  "naar_id": "<id>",
  "scope": "<beschrijving>",
  "geldig_van": 1234567890,
  "geldig_tot": 1234567890
}
```
