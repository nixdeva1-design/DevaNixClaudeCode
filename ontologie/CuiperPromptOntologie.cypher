// ─── CuiperHeader ───────────────────────────────────────────────────────────
// ULID:          01COMP039PROMPTCYPHER000
// Naam:          ontologie/CuiperPromptOntologie.cypher
// Erft via:      CuiperCore → CuiperDonut → CuiperPromptExportOperator
// Aangemaakt:    CuiperStapNr 53
// Gewijzigd:     CuiperStapNr 54 — 2026-04-08
// ────────────────────────────────────────────────────────────────────────────
// CuiperPromptOntologie.cypher
// Neo4j Cypher schema: constraints, indexes en laadpatronen
// Erft via: Cuiper → CuiperCore → CuiperDonut → CuiperPromptExportOperator
//
// CuiperStapNr: 53  ULID: 01KNN8GN4Z9CPS2V9E5RRWQC59
// Aangemaakt:    2026-04-08
// Vereist:       Neo4j >= 5.0
//
// Gekozen opties (nabeschouwing):
//   Graph model i.p.v. tabellen: de relaties tussen vraag → beredenering → antwoord
//   zijn intrinsiek graph-structuren. Neo4j maakt traversal over sessie-ketens
//   en Markov-transitie-paden direct opvraagbaar zonder JOIN.
//   MERGE i.p.v. CREATE: MERGE is idempotent — meerdere keren draaien is veilig.
//   CREATE zou duplicaten aanmaken, wat /dev/null verbod equivalent is in graph context.
//   Labels in PascalCase: Neo4j conventie. Properties in snake_case: CuiperTaal.
//
// Laadopdracht (via neo4j-admin of cypher-shell):
//   cypher-shell -u neo4j -p <wachtwoord> --file ontologie/CuiperPromptOntologie.cypher
//
// /dev/null verbod: MERGE met ON MATCH/ON CREATE — geen stille overschrijving.

// ─── Node labels ─────────────────────────────────────────────────────────────
//   :CuiperVraagPrompt        — gebruikersvraag
//   :CuiperBeredeneringPrompt — redenering van ClaudeCode
//   :CuiperAntwoordPrompt     — antwoord van ClaudeCode
//   :CuiperSessie             — sessie container
//   :CuiperHiveLid            — wie spreekt (Cuiper=1, Deva=2, ClaudeCode=3)

// ─── Relatie types ────────────────────────────────────────────────────────────
//   (CuiperVraagPrompt)-[:HEEFT_BEREDENERING]->(CuiperBeredeneringPrompt)
//   (CuiperVraagPrompt)-[:HEEFT_ANTWOORD]---->(CuiperAntwoordPrompt)
//   (CuiperSessie)----[:BEVAT]-------------(CuiperVraagPrompt)
//   (CuiperHiveLid)--[:STELT_VRAAG]-------(CuiperVraagPrompt)
//   (CuiperHiveLid)--[:GEEFT_ANTWOORD]---(CuiperAntwoordPrompt)

// ─── Constraints (uniciteit + aanwezigheid) ──────────────────────────────────

CREATE CONSTRAINT cuiper_vraag_ulid IF NOT EXISTS
    FOR (v:CuiperVraagPrompt)
    REQUIRE v.ulid IS UNIQUE;

CREATE CONSTRAINT cuiper_bered_ulid IF NOT EXISTS
    FOR (b:CuiperBeredeneringPrompt)
    REQUIRE b.ulid IS UNIQUE;

CREATE CONSTRAINT cuiper_antw_ulid IF NOT EXISTS
    FOR (a:CuiperAntwoordPrompt)
    REQUIRE a.ulid IS UNIQUE;

CREATE CONSTRAINT cuiper_sessie_ulid IF NOT EXISTS
    FOR (s:CuiperSessie)
    REQUIRE s.sessie_ulid IS UNIQUE;

// ─── Indexes ─────────────────────────────────────────────────────────────────

CREATE INDEX cuiper_vraag_stap IF NOT EXISTS
    FOR (v:CuiperVraagPrompt) ON (v.cuiper_stap_nr);

CREATE INDEX cuiper_bered_stap IF NOT EXISTS
    FOR (b:CuiperBeredeneringPrompt) ON (b.cuiper_stap_nr);

CREATE INDEX cuiper_antw_stap IF NOT EXISTS
    FOR (a:CuiperAntwoordPrompt) ON (a.cuiper_stap_nr);

CREATE INDEX cuiper_antw_uitkomst IF NOT EXISTS
    FOR (a:CuiperAntwoordPrompt) ON (a.uitkomst);

CREATE INDEX cuiper_bered_markov IF NOT EXISTS
    FOR (b:CuiperBeredeneringPrompt) ON (b.markov_uitkomst);

// ─── Full-text indexes ────────────────────────────────────────────────────────

CREATE FULLTEXT INDEX cuiper_vraag_fts IF NOT EXISTS
    FOR (v:CuiperVraagPrompt) ON EACH [v.tekst];

CREATE FULLTEXT INDEX cuiper_antw_fts IF NOT EXISTS
    FOR (a:CuiperAntwoordPrompt) ON EACH [a.tekst, a.nabeschouwing, a.fout_melding];

// ─── MERGE patroon: CuiperVraagPrompt ────────────────────────────────────────
// Template — vul parameters in via CuiperPromptExporter.sh gegenereerde Cypher

// MERGE (s:CuiperSessie {sessie_ulid: $sessie_ulid})
// ON CREATE SET s.aangemaakt = $unix_ms
//
// MERGE (v:CuiperVraagPrompt {ulid: $vraag_ulid})
// ON CREATE SET
//     v.cuiper_stap_nr = $cuiper_stap_nr,
//     v.sessie_ulid    = $sessie_ulid,
//     v.unix_ms        = $unix_ms,
//     v.branch         = $branch,
//     v.hive_nr_van    = $hive_nr_van,
//     v.hive_nr_naar   = $hive_nr_naar,
//     v.tekst          = $tekst,
//     v.bron           = $bron,
//     v.is_ci_notitie  = $is_ci_notitie,
//     v.aangemaakt     = $aangemaakt
// ON MATCH SET
//     v._conflict = true   // signaal: ULID al aanwezig — naar CuiperConflicten
//
// MERGE (s)-[:BEVAT]->(v)

// ─── MERGE patroon: CuiperBeredeneringPrompt ─────────────────────────────────

// MERGE (b:CuiperBeredeneringPrompt {ulid: $bered_ulid})
// ON CREATE SET
//     b.cuiper_stap_nr  = $cuiper_stap_nr,
//     b.sessie_ulid     = $sessie_ulid,
//     b.unix_ms         = $unix_ms,
//     b.redenering      = $redenering,
//     b.plan            = $plan,
//     b.markov_a        = $markov_a,
//     b.markov_b        = $markov_b,
//     b.markov_c        = $markov_c,
//     b.markov_uitkomst = $markov_uitkomst,
//     b.rollbackpunt    = $rollbackpunt,
//     b.tools_gebruikt  = $tools_gebruikt,
//     b.aangemaakt      = $aangemaakt
//
// MATCH (v:CuiperVraagPrompt {ulid: $vraag_ulid})
// MERGE (v)-[:HEEFT_BEREDENERING]->(b)

// ─── MERGE patroon: CuiperAntwoordPrompt ─────────────────────────────────────

// MERGE (a:CuiperAntwoordPrompt {ulid: $antw_ulid})
// ON CREATE SET
//     a.cuiper_stap_nr          = $cuiper_stap_nr,
//     a.sessie_ulid             = $sessie_ulid,
//     a.unix_ms                 = $unix_ms,
//     a.tekst                   = $tekst,
//     a.uitkomst                = $uitkomst,
//     a.nabeschouwing           = $nabeschouwing,
//     a.gekozen_optie           = $gekozen_optie,
//     a.afgewezen_opties        = $afgewezen_opties,
//     a.fout_code               = $fout_code,
//     a.fout_melding            = $fout_melding,
//     a.fout_locatie            = $fout_locatie,
//     a.conflict_beschrijving   = $conflict_beschrijving,
//     a.herstel_actie           = $herstel_actie,
//     a.aangemaakt              = $aangemaakt
//
// MATCH (v:CuiperVraagPrompt {ulid: $vraag_ulid})
// MERGE (v)-[:HEEFT_ANTWOORD]->(a)

// ─── Query: volledige Markov keten van een sessie ────────────────────────────
// Alle stappen in volgorde met transitie-uitkomst:
//
// MATCH (s:CuiperSessie {sessie_ulid: $sessie})-[:BEVAT]->(v:CuiperVraagPrompt)
// OPTIONAL MATCH (v)-[:HEEFT_BEREDENERING]->(b:CuiperBeredeneringPrompt)
// OPTIONAL MATCH (v)-[:HEEFT_ANTWOORD]->(a:CuiperAntwoordPrompt)
// RETURN
//     v.cuiper_stap_nr    AS stap,
//     v.tekst             AS vraag,
//     b.markov_uitkomst   AS markov,
//     b.rollbackpunt      AS rollback,
//     a.uitkomst          AS uitkomst,
//     a.nabeschouwing     AS nabeschouwing
// ORDER BY v.cuiper_stap_nr ASC

// ─── Query: alle mislukte stappen (rollback detectie) ────────────────────────
//
// MATCH (b:CuiperBeredeneringPrompt {markov_uitkomst: 'C!=B'})
// OPTIONAL MATCH (v:CuiperVraagPrompt)-[:HEEFT_BEREDENERING]->(b)
// RETURN v.cuiper_stap_nr, v.tekst, b.markov_a, b.markov_b, b.markov_c, b.rollbackpunt
// ORDER BY v.cuiper_stap_nr DESC
