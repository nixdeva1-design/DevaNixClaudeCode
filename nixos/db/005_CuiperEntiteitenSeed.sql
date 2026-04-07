-- 005_CuiperEntiteitenSeed.sql
-- Seed: alle bekende CuiperHive modules en entiteiten in cuiper.entiteiten
-- Seed: alle CuiperTaalSyntax termen vanuit CLAUDE.md § CuiperVocabulaire
--
-- Amendement-protocol: ON CONFLICT DO UPDATE — nooit weggooien
-- Volgorde: taal_syntax eerst, dan entiteiten (FK referentie)

-- ─── CuiperTaalSyntax — precisie-vocabulaire ─────────────────────────────────

INSERT INTO cuiper.taal_syntax (ulid, unix_ts, term, definitie, wat_ik_doe, externe_state, overleeft_sessie, versie_nr)
VALUES
  ('01TAAL0000000000000000001', 1775559000, 'Redeneren',
   'Tekst genereren intern. Nooit zichtbaar tenzij geschreven in response.',
   'Tekst genereren intern',         'Nee', 'Nee', '0.1.0'),
  ('01TAAL0000000000000000002', 1775559000, 'Ontwerpen',
   'Een plan formuleren als tekst in response. Bestaat alleen in het gesprek.',
   'Plan formuleren als tekst',      'Nee', 'Nee', '0.1.0'),
  ('01TAAL0000000000000000003', 1775559000, 'Lezen',
   'Read/Grep/Glob/Bash uitvoeren om bestanden of git output te bekijken. Read-only.',
   'Read/Grep/Glob/Bash uitvoeren',  'Nee', 'Nee', '0.1.0'),
  ('01TAAL0000000000000000004', 1775559000, 'Schrijven',
   'Write/Edit tool: bestand aanmaken of wijzigen op lokale disk.',
   'Write/Edit tool uitvoeren',      'Lokale disk', 'Nee (tot commit)', '0.1.0'),
  ('01TAAL0000000000000000005', 1775559000, 'Committen',
   'git commit uitvoeren. Staat vastgelegd in lokale git history. NIET op remote.',
   'git commit uitvoeren',           'Lokale git', 'Nee (tot push)', '0.1.0'),
  ('01TAAL0000000000000000006', 1775559000, 'Pushen',
   'git push uitvoeren. Staat op remote branch. Overleeft sessie-einde en crashes.',
   'git push uitvoeren',             'Remote', 'Ja', '0.1.0'),
  ('01TAAL0000000000000000007', 1775559000, 'Vastleggen',
   'logs/trail/ schrijven + committen + pushen. Volledige cyclus. Niets minder.',
   'schrijven + committen + pushen', 'Remote', 'Ja', '0.1.0'),
  ('01TAAL0000000000000000008', 1775559000, 'Bouwen',
   'Schrijven + testen + verificeren. Impliceert NIET automatisch committen of pushen.',
   'schrijven + testen + verificeren','Lokale disk', 'Nee (tot commit)', '0.1.0'),
  ('01TAAL0000000000000000009', 1775559000, 'Plannen',
   'Een stap toevoegen aan TodoWrite of CuiperBacklog. Niet hetzelfde als uitvoeren.',
   'stap toevoegen aan backlog',     'Context/backlog', 'Nee', '0.1.0'),
  ('01TAAL000000000000000000A', 1775559000, 'Testen',
   'Verificatiecommando uitvoeren, output lezen. Geen state wijziging.',
   'verificatiecommando uitvoeren',  'Nee', 'Nee', '0.1.0'),
  ('01TAAL000000000000000000B', 1775559000, 'Verificeren',
   'CuiperVerify.sh uitvoeren, Markov C bepalen (C==B of rollback).',
   'CuiperVerify.sh uitvoeren',      'Nee', 'Nee', '0.1.0'),
  ('01TAAL000000000000000000C', 1775559000, 'Activeren',
   'Service of script starten via systemctl/bash. OS runtime state wijzigt.',
   'systemctl/bash starten',         'OS runtime', 'Tot reboot', '0.1.0'),
  ('01TAAL000000000000000000D', 1775559000, 'Deployen',
   'Activeren op productiesysteem na verificatie.',
   'activeren op productiesysteem',  'OS + extern', 'Ja', '0.1.0')
ON CONFLICT (term) DO UPDATE SET
  definitie        = EXCLUDED.definitie,
  wat_ik_doe       = EXCLUDED.wat_ik_doe,
  externe_state    = EXCLUDED.externe_state,
  overleeft_sessie = EXCLUDED.overleeft_sessie,
  aangepast_ts     = EXCLUDED.unix_ts;

-- ─── CuiperEntiteiten — alle modules ─────────────────────────────────────────

INSERT INTO cuiper.entiteiten (ulid, unix_ts, naam, omschrijving, werking, status, versie_nr, module_type, cuiper_in, cuiper_out, erft_van)
VALUES
  -- Protocol scripts
  ('01ENT0PROMPTCOUNTER0000001', 1775559000,
   'CuiperPromptCounter',
   'Dynamische context-drempel bewaking + auto-vastleggen trail logs',
   'Verhoogt sessie teller na elke respons. Berekent drempel (avg*0.80/0.95). Commit+push trail. Jaeger span.',
   'ACTIEF', '0.2.0', 'script', 'hook', 'trail,git,push',
   'CuiperClaudeCodeTakenlijst'),

  ('01ENT0KLAARMELDING00000002', 1775559000,
   'CuiperKlaarMelding',
   'Verplichte klaar-melding aan het einde van elke ClaudeCode respons',
   'Toont CuiperStapNr, ULID, commit, branch, sessie voortgang, backlog samenvatting.',
   'ACTIEF', '0.2.0', 'script', 'args', 'stdout',
   'CuiperKlaarMeldingOperator'),

  ('01ENT0SESSIESTART000000003', 1775559000,
   'CuiperSessieStart',
   'PreToolUse hook — schrijft SESSIE_OPEN log + verhoogt CuiperSessieNr',
   'Detecteert nieuwe sessie via COUNT_TS delta > 300s. Reset teller. Schrijft sessie-open log.',
   'ACTIEF', '0.2.0', 'script', 'hook', 'trail,file',
   'CuiperClaudeCodeTakenlijst'),

  ('01ENT0BACKLOGPLANNER000004', 1775559000,
   'CuiperBacklogPlanner',
   'Backlog beheer: toon, prioriteit, status, samenvatting',
   'Leest CuiperBacklog.md. Ondersteunt subcommando: toon/samenvatting/prioriteit/status.',
   'ACTIEF', '0.2.0', 'script', 'args,file', 'stdout,file',
   'CuiperBacklogOperator'),

  ('01ENT0CONTEXTDUMP00000005', 1775559000,
   'CuiperContextDump',
   'Dump ClaudeCode context na elke CuiperStapNr',
   'Schrijft ClaudeCodeContext.md + ClaudeCodeContext.jsonl per stap.',
   'ACTIEF', '0.2.0', 'script', 'args', 'file',
   'CuiperZelfcontroleAI'),

  ('01ENT0IDEE0000000000000006', 1775559000,
   'CuiperIdee',
   'Registreer ci:: ideeën als WEES in CuiperBacklog + CuiperWezen.jsonl',
   'Extraheert tekst na ci:: prefix. Schrijft naar backlog en wezen JSONL. Conflicten gesedimenteerd.',
   'ACTIEF', '0.2.0', 'script', 'args', 'file',
   'CuiperTrailLogOperator'),

  ('01ENT0JAEGERSPAN00000007', 1775559000,
   'CuiperJaegerSpan',
   'Stuurt een Jaeger tracing span voor elke prompt',
   'POST naar Jaeger UDP of HTTP collector. trace_id + span_id + naam + start/eind + status.',
   'ACTIEF', '0.2.0', 'script', 'args', 'zenoh,stdout',
   'CuiperClaudeCodeTakenlijst'),

  ('01ENT0LISTENER00000000008', 1775559000,
   'CuiperListener',
   'Voert commando''s uit namens CuiperHive en registreert uitkomst in trail',
   'Wikkelt elke shell-operatie in Cuip (CAN→Voltooid/Mislukt). Output naar trail.',
   'ACTIEF', '0.2.0', 'script', 'args,stdin', 'trail,stdout',
   'CuiperClaudeCodeTakenlijst'),

  ('01ENT0LOG000000000000009', 1775559000,
   'CuiperLog',
   'Schrijft gestructureerde trail log naar logs/trail/',
   'Maakt log file aan met ULID, timestamp, vraag, redenering, antwoord, plan, Markov staten.',
   'ACTIEF', '0.2.0', 'script', 'args', 'file',
   'CuiperTrailLogOperator'),

  ('01ENT0SENTINEL0000000010', 1775559000,
   'CuiperSentinel',
   'Bewaakt de staat van de repo continu — redt bij onderbreking',
   'Draait als achtergrond proces. Detecteert sessie-onderbreking/stroomuitval. Auto-commit+push.',
   'ACTIEF', '0.2.0', 'script', 'hook', 'trail,git,push',
   'CuiperClaudeCodeTakenlijst'),

  ('01ENT0STEWARD000000000011', 1775559000,
   'CuiperSteward',
   'Beheert continuïteit van ontwerpen en staat — proactief',
   'Exporteert context. Bewaakt trail volledigheid. Vult ontbrekende logs aan.',
   'ACTIEF', '0.2.0', 'script', 'hook,git', 'trail,file',
   'CuiperClaudeCodeTakenlijst'),

  ('01ENT0ULID00000000000012', 1775559000,
   'CuiperUlid',
   'Genereert een ULID (Universally Unique Lexicographically Sortable ID)',
   'Timestamp-deel (10 chars) + random-deel (16 chars). Output naar stdout.',
   'ACTIEF', '0.2.0', 'script', 'none', 'stdout',
   'CuiperClaudeCodeTakenlijst'),

  ('01ENT0VERIFY000000000013', 1775559000,
   'CuiperVerify',
   'Cuiper3MarkovchainProtocol verificatie: C==B of rollback naar A',
   'Vergelijkt NaVerwacht met Verwacht. Bij match: versie+1. Bij mismatch: git checkout rollback.',
   'ACTIEF', '0.2.0', 'script', 'args,file', 'file,stdout',
   'CuiperClaudeCodeTakenlijst'),

  ('01ENT0MODULELIB000000014', 1775559000,
   'CuiperModuleLib',
   'Gedeelde bibliotheek voor alle CuiperProtocol + CuiperGuest scripts',
   'Biedt verbose (/v /vaan /vuit), help (/h /haan /huit), CuiperIn/CuiperOut definities, cuiper_register_module().',
   'ACTIEF', '0.2.0', 'script', 'args', 'stderr,postgres',
   'CuiperClaudeCodeTakenlijst'),

  -- Guest scripts
  ('01ENT0AGENT000000000015', 1775559000,
   'CuiperAgent',
   'CuiperHive agent op gastcomputer — diagnose → connect → listener',
   'Voert standaard sequentie uit. Implementeert Cuiper3MarkovchainProtocol volledig.',
   'ACTIEF', '0.2.0', 'script', 'args,stdin', 'trail,stdout',
   'CuiperDonut'),

  ('01ENT0CONNECT000000000016', 1775559000,
   'CuiperConnect',
   'Verbindt gastcomputer met hoofdnode (SSH/WireGuard/Tailscale)',
   'Transport automatisch bepaald. Schrijft verbindingsstaat naar trail.',
   'ACTIEF', '0.2.0', 'script', 'args', 'trail,stdout',
   'CuiperDonut'),

  ('01ENT0DIAGNOSE00000000017', 1775559000,
   'CuiperDiagnose',
   'Volledige hardware en OS diagnose op gastcomputer',
   'Rapporteert CPU, RAM, opslag, netwerk, OS naar stdout + logfile.',
   'ACTIEF', '0.2.0', 'script', 'none', 'stdout,file',
   'CuiperDonut'),

  -- Rust crates
  ('01ENT0CUIPERCORE00000018', 1775559000,
   'cuiper-core',
   'CuiperHive kern types: Cuip, CuiperIOBus, CuiperWereld, Markov, Donut',
   'Cuip (kleinste eenheid) + hash + CuiperRegel vector. CuiperIOBus polymorf agnostisch. CuiperWaarde.',
   'ACTIEF', '0.2.0', 'rust_crate', 'none', 'none',
   'CuiperDonut'),

  ('01ENT0CUIPERDATALOG00019', 1775559000,
   'cuiper-datalog',
   'Datalog/Prolog inferentie engine in Rust',
   'Feiten, regels, motor voor forward-chaining inferentie. Geen Java afhankelijkheid.',
   'ACTIEF', '0.1.0', 'rust_crate', 'none', 'none',
   'CuiperDonut'),

  ('01ENT0CUIPERBUS000000020', 1775559000,
   'cuiper-bus',
   'Zenoh bus wrapper + namespace traits voor signaal routing',
   'CuiperBus trait, namespace isolatie, signaal types.',
   'ACTIEF', '0.1.0', 'rust_crate', 'zenoh', 'zenoh',
   'CuiperDonut'),

  ('01ENT0CUIPERROUTER00021', 1775559000,
   'cuiper-router',
   'Signaal routing engine — namespace-gebaseerde brug',
   'CuiperRouter, CuiperRoutegel, CuiperBrug. Matcht namespace patronen.',
   'ACTIEF', '0.1.0', 'rust_crate', 'zenoh', 'zenoh',
   'CuiperDonut'),

  -- NixOS modules
  ('01ENT0NIXSERVICES000022', 1775559000,
   'CuiperServices',
   'Hoofdmodule voor alle CuiperHive services (NixOS)',
   'Kafka, Ollama, n8n, MindsDB, MLflow, Jaeger — allen via CuiperPorts.nix.',
   'ACTIEF', '0.1.0', 'nix_module', 'none', 'none',
   'CuiperDonut'),

  ('01ENT0NIXPORTS0000023', 1775559000,
   'CuiperPorts',
   'Centrale poortregistry — geen conflicten, één bron van waarheid',
   'Definieert alle poorten als Nix opties. Conflictdetectie via CuiperPortConflictRegistry.',
   'ACTIEF', '0.1.0', 'nix_module', 'none', 'none',
   'CuiperDonut'),

  ('01ENT0NIXDATABASES00024', 1775559000,
   'CuiperDatabases',
   'PostgreSQL + pgvector + GIN + DuckDB + Neo4j + MongoDB configuratie',
   'Init scripts per DB. btrfs subvolumes. Rol-isolatie per context.',
   'ACTIEF', '0.1.0', 'nix_module', 'none', 'none',
   'CuiperDonut'),

  -- Ontologie
  ('01ENT0ONTOLOGIE000000025', 1775559000,
   'CuiperOerOntologie',
   'SQL schema voor de kern-ontologie van CuiperHive',
   'Entiteiten, relaties, hive-definities. GIN full-text index. Amendement-protocol.',
   'ACTIEF', '0.1.0', 'sql_schema', 'none', 'postgres',
   'CuiperDonut'),

  ('01ENT0ENTITEITENTABEL026', 1775559000,
   'CuiperEntiteitenTabel',
   'PostgreSQL tabel voor alle modules en entiteiten in cuiper.entiteiten',
   'ulid, unix_ts, naam, omschrijving, werking, status, versie_nr, cuiper_in, cuiper_out, relaties per kolom. GIN index.',
   'ACTIEF', '0.1.0', 'sql_schema', 'none', 'postgres',
   'CuiperOerOntologie')

ON CONFLICT (naam) DO UPDATE SET
  omschrijving   = EXCLUDED.omschrijving,
  werking        = EXCLUDED.werking,
  status         = EXCLUDED.status,
  versie_nr      = EXCLUDED.versie_nr,
  module_type    = EXCLUDED.module_type,
  cuiper_in      = EXCLUDED.cuiper_in,
  cuiper_out     = EXCLUDED.cuiper_out,
  erft_van       = EXCLUDED.erft_van,
  aangepast_ts   = EXCLUDED.unix_ts;
