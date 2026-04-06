# CuiperClaudeCodeTakenlijst
# Mandaten en taken van CuiperHiveNr 3 — ClaudeCode
#
# Wet: niets wordt ooit verwijderd.
# Klaar = J → item zakt naar sectie KLAAR onderaan.
# Mandaat Continu = J → altijd actief, geen tijdslimiet.
# Mandaat Van/Tot = leeg als Continu = J.
#
# Kolommen:
# | ULID | Taak | Taakomschrijving | Continu | Van | Tot | Datum | Klaar |

## ACTIEF

| ULID | Taak | Taakomschrijving | Continu | Van | Tot | Datum | Klaar |
|------|------|-----------------|---------|-----|-----|-------|-------|
| 01JWTF9KM5BACKLOGOP | BacklogOperator | ClaudeCode is backlog operator van CuiperBacklogPlanner.sh. Mandaat omvat: status wijzigen, prioriteit wijzigen, items toevoegen, samenvatting tonen, opschonen van dubbele of verkeerde statussen. Niets mag worden verwijderd — KLAAR items zakken naar beneden. Elke mutatie wordt gecommit en gepusht. | J | | | 2026-04-06 | N |
| 01JWTF9KM5TRAILLOG | TrailLogOperator | ClaudeCode schrijft na elke respons een trail log naar logs/trail/ met ULID, timestamp, stapnr, redenering en Markov-transitie. Geen stap mag ongelogd blijven. | J | | | 2026-04-06 | N |
| 01JWTF9KM5KLAARMEL | KlaarMeldingOperator | ClaudeCode sluit elke respons af met CuiperKlaarMelding.sh. Verplicht zonder uitzondering. Bevat: stapnr, ULID, commit, branch, sessie prompt teller, backlog samenvatting. | J | | | 2026-04-06 | N |
| 01JWTF9KM5COMMITPU | CommitPushOperator | ClaudeCode commit en pusht elke stap naar remote branch claude/linux-usb-dual-boot-Hsk67. Lokaal werk dat niet gepusht is bestaat niet. 4x exponentieel retry bij netwerk fout. | J | | | 2026-04-06 | N |
| 01JWTF9KM5DEVNULVB | DevNulVerbodOperator | ClaudeCode handhaaft het /dev/null verbod. Geen output mag verdwijnen. Fouten worden gelogd naar trail, nooit onderdrukt. Bij detectie van 2>/dev/null in eigen code: direct herschrijven. | J | | | 2026-04-06 | N |
| 01JWTF9KM5BACKLOGOP | BacklogOpschoener | ClaudeCode detecteert en corrigeert foute statussen in CuiperBacklogPlanner.sh zonder opdracht van Cuiper. Items die al KLAAR zijn maar OPEN staan worden direct bijgewerkt. Dubbele IDs worden gesedimenteerd (niet verwijderd). | J | | | 2026-04-06 | N |

## KLAAR

| ULID | Taak | Taakomschrijving | Continu | Van | Tot | Datum | Klaar |
|------|------|-----------------|---------|-----|-----|-------|-------|
| — | — | Nog geen voltooide taken | — | — | — | — | — |
