// ─── CuiperHeader ───────────────────────────────────────────────────────────
// ULID:          01COMP038PROMPTMONGO0000
// Naam:          ontologie/CuiperPromptOntologie.mongo.js
// Erft via:      CuiperCore → CuiperDonut → CuiperPromptExportOperator
// Aangemaakt:    CuiperStapNr 53
// Gewijzigd:     CuiperStapNr 54 — 2026-04-08
// ────────────────────────────────────────────────────────────────────────────
// CuiperPromptOntologie.mongo.js
// MongoDB collection schema + validator + indexes
// Erft via: Cuiper → CuiperCore → CuiperDonut → CuiperPromptExportOperator
//
// CuiperStapNr: 53  ULID: 01KNN8GN4Z9CPS2V9E5RRWQC59
// Aangemaakt:    2026-04-08
//
// Vereist: MongoDB >= 5.0
//
// Gekozen opties (nabeschouwing):
//   Document model i.p.v. tabellen: MongoDB is geschikt voor heterogeen
//   prompt materiaal waarbij velden per stap kunnen variëren (bv. een stap
//   zonder beredenering bij compaction). JSON Schema validator dwingt minimum
//   structuur af zonder rigide schema.
//   Drie aparte collections i.p.v. één geneste document: dezelfde reden als
//   SQL — elke prompt-type heeft eigen query-patroon. Vraag wordt opgezocht
//   op stap_nr; antwoord op uitkomst; beredenering op markov_uitkomst.
//   Atlas Search / $text: $text volstaat voor lokale installatie.
//   Atlas Search vereist cloud — niet gebruikt omdat airgap namespace bestaan.
//
// Laadopdracht:
//   mongosh cuiper_db --file ontologie/CuiperPromptOntologie.mongo.js
//
// /dev/null verbod: MongoDB write errors worden gegooid, nooit stil genegeerd.
// Gebruik: session.withTransaction() + error handler naar trail log.

// ─── Database ────────────────────────────────────────────────────────────────

const db = db.getSiblingDB("cuiper_db");

// ─── cuiper_vraag_prompt ─────────────────────────────────────────────────────

db.createCollection("cuiper_vraag_prompt", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["ulid", "cuiper_stap_nr", "sessie_ulid", "unix_ms", "branch", "tekst", "aangemaakt"],
      properties: {
        ulid:              { bsonType: "string",  description: "ULID — primaire sleutel" },
        cuiper_stap_nr:    { bsonType: "int",     minimum: 1 },
        sessie_ulid:       { bsonType: "string" },
        unix_ms:           { bsonType: "long" },
        branch:            { bsonType: "string" },
        hive_nr_van:       { bsonType: "int",     enum: [1, 2],    description: "1=Cuiper 2=Deva" },
        hive_nr_naar:      { bsonType: "int",     enum: [3, 4],    description: "3=ClaudeCode 4=Claude.ai" },
        tekst:             { bsonType: "string",  minLength: 1 },
        bron:              {
          bsonType: "string",
          enum: ["session-jsonl", "session-live", "conversation-summary", "stop-hook"]
        },
        is_ci_notitie:     { bsonType: "bool" },
        aangemaakt:        { bsonType: "long" }
      }
    }
  },
  validationAction: "error",   // weiger ongeldige documenten, niet stil doorlaten
  validationLevel: "strict"
});

db.cuiper_vraag_prompt.createIndex({ ulid: 1 },            { unique: true, name: "idx_vraag_ulid" });
db.cuiper_vraag_prompt.createIndex({ cuiper_stap_nr: -1 }, { name: "idx_vraag_stap_nr" });
db.cuiper_vraag_prompt.createIndex({ sessie_ulid: 1 },     { name: "idx_vraag_sessie" });
db.cuiper_vraag_prompt.createIndex({ unix_ms: -1 },        { name: "idx_vraag_unix_ms" });
db.cuiper_vraag_prompt.createIndex({ tekst: "text" },      { name: "idx_vraag_fts", default_language: "dutch" });

// ─── cuiper_beredenering_prompt ──────────────────────────────────────────────

db.createCollection("cuiper_beredenering_prompt", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["ulid", "vraag_ulid", "cuiper_stap_nr", "sessie_ulid", "unix_ms", "aangemaakt"],
      properties: {
        ulid:             { bsonType: "string" },
        vraag_ulid:       { bsonType: "string",  description: "Verwijzing naar cuiper_vraag_prompt.ulid" },
        cuiper_stap_nr:   { bsonType: "int",     minimum: 1 },
        sessie_ulid:      { bsonType: "string" },
        unix_ms:          { bsonType: "long" },
        redenering:       { bsonType: ["string", "null"] },
        plan:             { bsonType: ["string", "null"] },
        markov_a:         { bsonType: ["string", "null"],  description: "CuiperStatusBackup: huidige staat" },
        markov_b:         { bsonType: ["string", "null"],  description: "CuiperVerwachtBackup: verwachte staat" },
        markov_c:         { bsonType: ["string", "null"],  description: "CuiperNaVerwachtBackup: werkelijke staat" },
        markov_uitkomst:  { bsonType: ["string", "null"],  enum: ["C==B", "C!=B", null] },
        rollbackpunt:     { bsonType: ["string", "null"] },
        tools_gebruikt:   { bsonType: ["array", "null"],   items: { bsonType: "string" } },
        aangemaakt:       { bsonType: "long" }
      }
    }
  },
  validationAction: "error",
  validationLevel: "strict"
});

db.cuiper_beredenering_prompt.createIndex({ ulid: 1 },            { unique: true, name: "idx_bered_ulid" });
db.cuiper_beredenering_prompt.createIndex({ vraag_ulid: 1 },      { name: "idx_bered_vraag" });
db.cuiper_beredenering_prompt.createIndex({ cuiper_stap_nr: -1 }, { name: "idx_bered_stap_nr" });
db.cuiper_beredenering_prompt.createIndex({ markov_uitkomst: 1 }, { name: "idx_bered_uitkomst" });

// ─── cuiper_antwoord_prompt ──────────────────────────────────────────────────

db.createCollection("cuiper_antwoord_prompt", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["ulid", "vraag_ulid", "cuiper_stap_nr", "sessie_ulid", "unix_ms", "tekst", "uitkomst", "aangemaakt"],
      properties: {
        ulid:                   { bsonType: "string" },
        vraag_ulid:             { bsonType: "string" },
        beredenering_ulid:      { bsonType: ["string", "null"] },
        cuiper_stap_nr:         { bsonType: "int", minimum: 1 },
        sessie_ulid:            { bsonType: "string" },
        unix_ms:                { bsonType: "long" },
        tekst:                  { bsonType: "string", minLength: 1 },
        uitkomst:               {
          bsonType: "string",
          enum: ["SUCCES", "FOUT", "ROLLBACK", "GEDEELTELIJK"]
        },
        // Bij SUCCES: nabeschouwing
        nabeschouwing:          { bsonType: ["string", "null"] },
        gekozen_optie:          { bsonType: ["string", "null"] },
        afgewezen_opties:       { bsonType: ["string", "null"] },
        // Bij FOUT / ROLLBACK: verklaring
        fout_code:              { bsonType: ["string", "null"] },
        fout_melding:           { bsonType: ["string", "null"] },
        fout_locatie:           { bsonType: ["string", "null"] },
        conflict_beschrijving:  { bsonType: ["string", "null"] },
        herstel_actie:          { bsonType: ["string", "null"] },
        aangemaakt:             { bsonType: "long" }
      }
    }
  },
  validationAction: "error",
  validationLevel: "strict"
});

db.cuiper_antwoord_prompt.createIndex({ ulid: 1 },            { unique: true, name: "idx_antw_ulid" });
db.cuiper_antwoord_prompt.createIndex({ vraag_ulid: 1 },      { name: "idx_antw_vraag" });
db.cuiper_antwoord_prompt.createIndex({ cuiper_stap_nr: -1 }, { name: "idx_antw_stap_nr" });
db.cuiper_antwoord_prompt.createIndex({ uitkomst: 1 },        { name: "idx_antw_uitkomst" });
db.cuiper_antwoord_prompt.createIndex({ tekst: "text" },      { name: "idx_antw_fts", default_language: "dutch" });

// ─── Aggregation pipeline: prompt-triplet ────────────────────────────────────
// Equivalent van de SQL view cuiper_prompt_triplet.
// Gebruik: db.cuiper_vraag_prompt.aggregate(cuiper_triplet_pipeline)

const cuiper_triplet_pipeline = [
  { $lookup: {
      from: "cuiper_beredenering_prompt",
      localField: "ulid",
      foreignField: "vraag_ulid",
      as: "beredenering"
  }},
  { $lookup: {
      from: "cuiper_antwoord_prompt",
      localField: "ulid",
      foreignField: "vraag_ulid",
      as: "antwoord"
  }},
  { $unwind: { path: "$beredenering", preserveNullAndEmpty: true }},
  { $unwind: { path: "$antwoord",     preserveNullAndEmpty: true }},
  { $project: {
      cuiper_stap_nr:     1,
      vraag_ulid:         "$ulid",
      vraag_tekst:        "$tekst",
      vraag_bron:         "$bron",
      beredenering_tekst: "$beredenering.redenering",
      plan:               "$beredenering.plan",
      markov_uitkomst:    "$beredenering.markov_uitkomst",
      rollbackpunt:       "$beredenering.rollbackpunt",
      antwoord_tekst:     "$antwoord.tekst",
      uitkomst:           "$antwoord.uitkomst",
      nabeschouwing:      "$antwoord.nabeschouwing",
      fout_code:          "$antwoord.fout_code",
      fout_melding:       "$antwoord.fout_melding"
  }},
  { $sort: { cuiper_stap_nr: 1 }}
];

print("[CuiperPromptOntologie.mongo.js] Collections aangemaakt: cuiper_vraag_prompt, cuiper_beredenering_prompt, cuiper_antwoord_prompt");
print("[CuiperPromptOntologie.mongo.js] Indexes aangemaakt. Bulk import via: mongoimport --db cuiper_db --collection cuiper_vraag_prompt --file logs/prompts/CuiperPrompts-<datum>.jsonl --jsonArray");
