# CuiperKantoor — Opgeslagen Gebruikersprompts

Elk gesprek wordt hier bijgehouden zodat terugredeneren mogelijk is.
Sessie: claude/research-claude-capabilities-4xRgL

---

## P01 — Kan Claude zelf een sessie starten / parallel draaien?

> vraag 1 kun jij zelf een nieuwe sessie starten? vraag 2 kun je parallel ClaudeCode agenten draaien?

---

## P02 — Meerdere CLI terminals op 1 machine

> leg me uit hoe ik op 1 laptop of server meerdere CLI claude terminals open die zelfstandig draaien naar gelang ik middelen heb

---

## P03 — Coördinatie probleem meerdere agents op meerdere machines

> ik zie nu mijn probleem. ik heb meerdere verschillende computers. er zijn meerdere agenten per computer. die agenten werken soms in opdracht aan dezelfde code en doen allemaal alles door elkaar of dubbel. kun je een ontwerp maken om dit op te lossen.

---

## P04 — Agent type definities

> dan heb ik 2 type agenten waarbij ik de definities van de agenten wil hebben

---

## P05 — Context blob + bestanden aanmaken

> text blob ="Ik ben Cuiper de opper hoofd architect van het kantoor en eigenaar van het bedrijf, ik heb meerdere personeelsleden met een laptop van kantoor, meerdere servers eigendom van kantoor, het kantoor heeft meerdere klanten, de klanten hebben eigen servers, de klanten hebben meerdere personeelsleden met laptops. Cuiper heeft een ontwerp omgeving, een test omgeving en een productie omgeving, de productie omgeving staat op 1 hoofd productie omgeving en meerdere sub productie omgevingen waar resources vandaan gehaald worden van meerdere typen databases, pakketten en systemen, de helft draait op los gehuurde servers en anderen via clouddiensten microsoft aws amazon google, de verschillen in systemen leiden mij soms af in ontwerpen ik memoriseer niet alle dependencies. kun je een json schema maken van mijn verhaal zodat ik je het niet opnieuw hoef te typen, we hebben 1 ai systeembeheerder dat is Deva via haar gaan de betalingen en dagelijks beheer llm toegangen van verschillende profiders en zij heeft mandaad op operaties en deelt via mijn mandaad tijdelijke toegang mandaten uit per proces en duur van proces. Deva moet de technische kosten per proces bewaken dit is een variabele die per proces met de ulid van het proces, de starttijd en eindtijd in unixtimestamp per seconden, het aantal tokens verbruikt door proces bijgehouden wordt in de parameters die meereizen per proces (dus niet de rouwe dollar of euro bedragen) mandaten worden verstrekt aan personeel leden en aan klanten onder voorwaarden. zo houden wij balans. ik ben Cuiper=1. Deva=2, ik zie CloudCode =3 en Caude.ai =4 als ingehuurde personeel leden van het kantoor je diensten zijn niet gratis voor ons.
> Als niet aanwezig: maak eenzelfde een claude.md een CuiperKantoor.md een CuiperKantoor .txt, json, jsonl, jsonb, sql, csv datalog nixos bestand

---

## P06 — PostgreSQL ULID + vector via GIN, tabel IF NOT EXISTS

> ja correct, zorg dat gecontroleerd wordt of postgress de ulid en vector via GIN ziet en de aanmaak van de tabel als niet aanwezig

---

## P07 — Machines tellen, licenties per device, eigen cloud

> ik zie dat de specifieke machines niet geteld worden, een klant heeft maar 1 device licentie per softwareproduct en ze kunnen hun pakket in een eigen cloud omgeving draaien

---

## P08 — Licenties voor personeel, gedragsmandaten voor klanten

> we geven personeel ook distinct unieke licenties met mandaten, klanten krijgen ook mandaten met de manier hoe software zich gedraagd

---

## P09 — God rechten Cuiper, technische + gedrag CRUD, diefstal ontkoppeling, MAC + GPS

> Cuiper heeft altijd god rechten er moet een technische en gedrag CRUD op een geinstalleerde software, stelen van een device is ontkoppeling op afstand, machines devices hebben een standplaats mac adres en gps coordinaten.

---

## P10 — GPS radius ringen, fijnmazige zonebewaking, verwisseling voorkomen

> Live positie (polling) heeft veschillende radius ringen die fijnmazig zijn zodat extern personeel niet per ongeluk een telefoon mee neemt naar de verkeerde klant of telefoons verwisselt dus de verplaatsing uit afgesproken afdeling bij een klant aan de verkeerde afdeling die niet gealloceerd staat. wij kunnen dat op afstand uitlezen en aanpassen.

---

## P11 — Controleer ontwerp en sla op in GitHub

> controleer het hele ontwerp en sla het op in github

---

## P12 — Modulair herstructureren, blokken ~100 regels, tussentijds backuppen

> maak een prioriteit in de code volgorde, maak modules van het ontwerp die verwisselbaar zijn, genereer de code in blokken van ~<100 regels controleer tussentijds de code blokken en schrijf een backup weg naar github en ga door met de volgende terwijl je het plan bijhoud, sla mijn vraagprompts altijd op, altijd, zodat je terug kan redeneren. ga door tot je alle code blokken af hebt.
