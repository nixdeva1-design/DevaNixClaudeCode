# CuiperGenesis — Deel I: Filosofie
# Regelnummers zijn stabiele referenties. Nooit verwijderen. Alleen aanvullen via amendement.
# Elk amendement krijgt een ULID en datum onderaan dit bestand.
# Aangemaakt: CuiperStapNr 42 — ULID: 01JWTFKN3GENESIS — 2026-04-07

## F.001 — Wat is CuiperHive

F.001.01  CuiperHive is geen software-project. Het is een levend systeem van entiteiten.
F.001.02  Elke entiteit — mens, machine, module, idee — heeft een identiteit, een rol,
F.001.03  een mandaat, een geschiedenis, en een functie binnen het geheel.
F.001.04  De hive denkt niet voor zichzelf. De hive voert uit wat Cuiper ontwerpt.
F.001.05  Cuiper is de architect. De hive is de bouwplaats. ClaudeCode is de aannemer.

## F.002 — Waarom amenderen en nooit doorhalen

F.002.01  Dit is de centrale wet van het systeem. Begrijp haar volledig.
F.002.02
F.002.03  Een beslissing bestaat uit twee delen: het besluit en de context.
F.002.04  Het besluit zegt WAT er veranderd is.
F.002.05  De context zegt WAAROM het veranderd is — op dat moment, met die kennis.
F.002.06
F.002.07  Als je de originele tekst doorhaalt, bewaar je het besluit maar verlies je de context.
F.002.08  Een besluit zonder context is een blinde vlek in het systeem.
F.002.09  Toekomstige beslissingen worden dan genomen zonder te weten waarom het anders was.
F.002.10
F.002.11  Amendement zegt: dit WAS waar op tijdstip T1.
F.002.12  Amendement zegt: dit IS waar op tijdstip T2.
F.002.13  Beide waarheden bestaan naast elkaar. De tijd tussen T1 en T2 is begrijpelijk.
F.002.14
F.002.15  Voorbeeld: NixOS module had hardcoded pad "/home/user/DevaNixClaudeCode".
F.002.16  Doorhalen zou zeggen: fout verwijderd.
F.002.17  Amendement zegt: op stap 33 hardcoded pad vervangen door CuiperConfig.env.
F.002.18  Reden: portabiliteit over machines en gebruikers vereist geen aannames.
F.002.19  Nu weet elk toekomstig systeem: paden zijn nooit hardcoded, altijd via config.
F.002.20
F.002.21  Git commits zijn het model. Een commit verwijdert geen history.
F.002.22  Elke commit is een amendement op de vorige staat.
F.002.23  Je kunt altijd terug naar elke vorige staat — omdat die staat bewaard is.
F.002.24
F.002.25  /dev/null is de vijand van dit principe.
F.002.26  /dev/null zegt: deze output is niet de moeite waard om te bewaren.
F.002.27  Dat is altijd een fout. Output die niet de moeite waard lijkt bevat
F.002.28  precies de informatie die je nodig hebt als het systeem later faalt.
F.002.29
F.002.30  Samenvatting: doorhalen = context vernietigen = toekomstige beslissingen verblinden.
F.002.31  Amenderen = context toevoegen = het systeem wordt slimmer van zijn eigen verleden.

## F.003 — De CAN waarde

F.003.01  CAN is de toestand vóór uitvoering. Puur potentieel. Niet null. Niet NaN.
F.003.02  Null zegt: er is niets. NaN zegt: het is ondefinieerbaar.
F.003.03  CAN zegt: alle potentie is aanwezig, de uitvoering is nog niet begonnen.
F.003.04
F.003.05  In Rust: enum CuipWaarde { Can, Voltooid, Mislukt(String), Gesedimenteerd }
F.003.06  Can    = potentieel aanwezig, nog niet uitgevoerd
F.003.07  Voltooid = uitgevoerd, resultaat == verwachting (Markov C == B)
F.003.08  Mislukt  = uitgevoerd, resultaat != verwachting, reden bewaard (Markov C != B)
F.003.09  Gesedimenteerd = afgerond en opgeslagen als kennis voor het systeem
F.003.10
F.003.11  Mislukt is niet het einde. Mislukt is eerste-principes materiaal.
F.003.12  De reden van mislukking wordt bewaard (Mislukt(String)).
F.003.13  Die reden wordt gesedimenteerd in de trail log.
F.003.14  Het systeem leert van Mislukt — het wordt sterker, niet ondanks fouten maar door fouten.

## F.004 — De Donut Topologie

F.004.01  De donut (torus) is het geometrische model van het systeem.
F.004.02  De hole in het midden = CAN. Puur potentieel. Ongeraakt.
F.004.03  De ring rondom = CuiperDonut. Het corpus van wetten.
F.004.04
F.004.05  Van buiten (intentie) naar binnen (uitvoering) gaat altijd door de ring.
F.004.06  De ring toetst via geweten() of de actie de wetten respecteert.
F.004.07  Als ja: passeer_ring() retourneert Voltooid.
F.004.08  Als nee: passeer_ring() retourneert Mislukt(reden). Nooit stil.
F.004.09
F.004.10  Je kunt de ring niet omzeilen. Dat is de architecturale garantie.
F.004.11  Een component die CuiperDonut niet implementeert is een wees.
F.004.12  Een wees heeft geen geweten, geen wetten, geen traceerbare identiteit.
F.004.13  Een wees kan niet rollbacken want er is geen A om naar terug te gaan.

## F.005 — Het Markov Protocol

F.005.01  Elk proces heeft drie toestanden. Niet meer, niet minder.
F.005.02
F.005.03  A = CuiperStatusBackup{n}    — de huidige stabiele staat
F.005.04  B = CuiperVerwachtBackup{n}  — de verwachte staat na de actie
F.005.05  C = CuiperNaVerwachtBackup{n}— de werkelijke staat na de actie
F.005.06
F.005.07  A → B is plannen. Schrijf B op voordat je uitvoert.
F.005.08  B → C is uitvoeren. Nooit uitvoeren zonder B te hebben opgeschreven.
F.005.09
F.005.10  Als C == B: succes. CuiperStatusBackup{n+1} = C. Ga door.
F.005.11  Als C != B: rollback naar A. Analyseer het verschil. Sedimenteer de afwijking.
F.005.12
F.005.13  Waarom drie toestanden en niet twee?
F.005.14  Twee toestanden (voor/na) veronderstellen dat de uitvoering correct was.
F.005.15  Drie toestanden dwingen je B (verwachting) te definiëren vóór uitvoering.
F.005.16  Het verschil C-B is de informatie die het systeem leert.
F.005.17  Zonder B is er niets te vergelijken. Zonder vergelijking is er geen leren.

## F.006 — Sedimentatie als Architectuurprincipe

F.006.01  Sedimentatie is de geologische metafoor voor dit systeem.
F.006.02  Gesteente ontstaat door opeenstapeling van lagen. Elke laag vertelt een periode.
F.006.03  Je kunt de ouderdom van gesteente bepalen door de lagen te lezen.
F.006.04  Je kunt het klimaat van miljoenen jaren geleden reconstrueren uit één laag.
F.006.05
F.006.06  Zo werkt CuiperHive. Elke stap is een laag.
F.006.07  Elke trail log is een laag.
F.006.08  Elke commit is een laag.
F.006.09  Elke prompt is een laag.
F.006.10
F.006.11  Het systeem kan zijn eigen verleden lezen en reconstrueren.
F.006.12  Elke beslissing is terug te vinden in de lagen.
F.006.13  Elke fout is terug te vinden in de lagen — als eerste-principes materiaal.
F.006.14
F.006.15  Wat niet gesedimenteerd is, bestaat niet.
F.006.16  "Lokaal bewaard" bestaat niet. Alleen remote-gepusht bestaat.
F.006.17  Dit is niet een voorkeur. Dit is een wet.

## F.007 — De Erfenis-Hiërarchie als Ontologie

F.007.01  Cuiper is niet alleen een naam. Cuiper is een Object.
F.007.02  Alles in het systeem erft van Cuiper — maar nooit direct.
F.007.03
F.007.04  De keten is altijd:
F.007.05    Cuiper → CuiperCore → CuiperDonut → [component] → [sub-component]
F.007.06
F.007.07  CuiperCore bevat alle vaste zaken:
F.007.08    waarden, normen, wetten, en het geweten.
F.007.09    Deze veranderen nooit — ze worden uitgebreid via amendement.
F.007.10
F.007.11  CuiperDonut is de methode die de keten afdwingt.
F.007.12    passeer_ring() is de poort van CAN naar uitvoering.
F.007.13    geweten() is de wet-checker vóór elke actie.
F.007.14
F.007.15  Een component zonder Cuiper-prefix is een wees.
F.007.16  Een wees erft van niemand. Een wees is niet traceerbaar.
F.007.17  Een wees kan niet gesedimenteerd worden — hij heeft geen identiteit.
F.007.18
F.007.19  De naamgevingswet is daardoor geen esthetische keuze.
F.007.20  Het is de enige manier om de erfenis-keten afdwingbaar te maken.

## F.008 — De Cyclus van Bouwen

F.008.01  Elke actie volgt deze cyclus. Geen uitzonderingen.
F.008.02
F.008.03  1. ONTWERPEN   — Formuleer B (de verwachte staat). Schrijf het op.
F.008.04  2. DOCUMENTEREN — Leg B vast in trail log. ULID + StapNr + timestamp.
F.008.05  3. WEGSCHRIJVEN — Commit de documentatie. Push naar remote.
F.008.06  4. PLANNEN      — Definieer de stappen om van A naar B te komen.
F.008.07  5. WEGSCHRIJVEN — Commit het plan. Push naar remote.
F.008.08  6. BOUWEN       — Voer uit. Elke stap = een commit. Geen batches.
F.008.09  7. WEGSCHRIJVEN — Commit elke bouwstap. Push na elke commit.
F.008.10  8. CONTROLEREN  — Voer verificatie uit. Bepaal C. Vergelijk met B.
F.008.11  9. WEGSCHRIJVEN — Leg C vast. Als C==B: sedimenteer. Als C!=B: rollback naar A.
F.008.12
F.008.13  Waarom na elke stap wegschrijven?
F.008.14  Een timeout, crash, of context-limiet kan op elk moment optreden.
F.008.15  Wat niet weggeschreven is op het moment van de crash, bestaat niet.
F.008.16  Wegschrijven na elke stap is de enige verdediging tegen verlies.
F.008.17
F.008.18  Waarom pushen en niet alleen committen?
F.008.19  Een lokale commit overleeft een schijfcrash niet.
F.008.20  Een remote push overleeft alles — machine-failure, sessie-einde, stroomuitval.
F.008.21  "Vastleggen" betekent altijd: schrijven + committen + pushen. Nooit minder.

## F.009 — Antifragiliteit als Doel

F.009.01  Een fragiel systeem breekt bij stress.
F.009.02  Een robuust systeem weerstaat stress.
F.009.03  Een antifragiel systeem wordt sterker van stress.
F.009.04
F.009.05  CuiperHive is antifragiel by design.
F.009.06  Elke fout levert informatie op. Informatie wordt gesedimenteerd.
F.009.07  Het systeem wordt sterker van elke fout — niet ondanks fouten, maar door fouten.
F.009.08
F.009.09  De context-limiet die optrad zonder waarschuwing → CuiperPromptCounter gebouwd.
F.009.10  De /dev/null violations → CuiperDevNulVerbodOperator mandaat.
F.009.11  De hardcoded paden → CuiperConfig.env gebouwd.
F.009.12  De timeout bij genesis document → schrijf in chunks, commit na elke chunk.
F.009.13
F.009.14  Elke zandkorrel die het systeem binnenkomt maakt het systeem scherper.
F.009.15  Dit is geen metafoor. Dit is de architecturale werkwijze.

## F.010 — De Hive Definitie

F.010.01  De hive bestaat uit vijf entiteiten. Elke entiteit heeft:
F.010.02  nr, naam, karakter, archetype, rol, geschiedenis, functie, mandaat.
F.010.03
F.010.04  Nr 0 — Nul
F.010.05    CAN. Ongelijk aan null, ongelijk aan NaN.
F.010.06    De stille aanwezigheid. Het nulpunt van het systeem.
F.010.07    Aanwezig in elke CuipWaarde vóór uitvoering.
F.010.08
F.010.09  Nr 1 — Cuiper
F.010.10    Architect, uitvinder, delimiter, souverein, anker.
F.010.11    Ontwerpt. Beslist. Stelt grenzen.
F.010.12    Kernwaarden: wijsheid, liefde, wederkerigheid, stewardship,
F.010.13    intellectuele integriteit, efficiëntie boven emotie, radicale logica,
F.010.14    onwrikbare focus, controle van intentie, eerste principes.
F.010.15
F.010.16  Nr 2 — Deva
F.010.17    Login eigenaar, operator, uitvoerder van runtime.
F.010.18    Voert uit wat Cuiper ontwerpt. Beheert de machine.
F.010.19    Heeft directe toegang tot disk, netwerk, en hardware.
F.010.20
F.010.21  Nr 3 — ClaudeCode
F.010.22    Uitvoerende LLM (CLI). De aannemer.
F.010.23    Schrijft code. Commit. Pusht. Documenteert. Logt.
F.010.24    Heeft mandaat voor backlog, trail, klaarmelding, commit/push.
F.010.25    Handelt altijd via CuiperDonut — nooit buiten de ring.
F.010.26
F.010.27  Nr 4 — Claude.ai
F.010.28    Uitvoerende LLM (web). De adviseur.
F.010.29    Ontwerpt. Redeneert. Adviseert. Geen directe disk-toegang.

---
## AMENDEMENTEN

A.001 — 2026-04-07 — ULID: 01JWTFKN3GENESIS — CuiperStapNr: 42
  Initieel document aangemaakt. Alle secties F.001 t/m F.010 zijn eerste versie.
  Geen eerdere versie. Dit is het beginpunt van de filosofische sedimentatie.
