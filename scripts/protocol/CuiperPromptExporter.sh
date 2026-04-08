#!/usr/bin/env bash

# ─── CuiperHeader ───────────────────────────────────────────────────────────
# ULID:          01COMP044PROMPTEXP0000000
# Naam:          scripts/protocol/CuiperPromptExporter.sh
# Erft via:      CuiperCore → CuiperDonut → CuiperClaudeCodeTakenlijst → CuiperPromptExportOperator
# Aangemaakt:    CuiperStapNr 41
# Gewijzigd:     CuiperStapNr 54 — 2026-04-08
# ────────────────────────────────────────────────────────────────────────────

# CuiperPromptExporter.sh
# Erft van: CuiperCore → CuiperDonut → CuiperClaudeCodeTakenlijst → CuiperPromptExportOperator
#
# Doel: Exporteer alle vraagprompts, redenering, antwoordprompts uit Claude sessies
#       naar logs/prompts/ als JSON en JSONL.
#       /dev/null verbod: alle fouten worden gelogd, niets stil weggegooid.
#
# Gebruik:
#   bash CuiperPromptExporter.sh                    # export huidige sessies
#   bash CuiperPromptExporter.sh --sessie <uuid>    # export specifieke sessie
#   bash CuiperPromptExporter.sh --alle             # export alle bekende sessies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! source "$SCRIPT_DIR/../../CuiperConfig.env"; then
    # CuiperConfig.env niet gevonden — fallback naar git root
    # Geen /dev/null: fout wordt gesedimenteerd via trail na initialisatie
    CUIPER_REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
    CUIPER_TRAIL_DIR="$CUIPER_REPO/logs/trail"
    mkdir -p "$CUIPER_TRAIL_DIR"
    echo "[DEVNUL_FIX] $(date +%s) CuiperConfig.env niet gevonden — fallback git root" \
        >> "$CUIPER_TRAIL_DIR/$(date +%s)-config-fallback-CUIPER.log"
fi

CLAUDE_SESSIONS_DIR="/root/.claude/projects/-home-user-DevaNixClaudeCode"
PROMPTS_DIR="$CUIPER_REPO/logs/prompts"
TIMESTAMP=$(date +%s)
ULID_PREFIX="01PROMPT"

mkdir -p "$PROMPTS_DIR"

log_fout() {
    echo "[FOUT] $*" >&2
    echo "[FOUT] $(date +%s) $*" >> "$CUIPER_TRAIL_DIR/${TIMESTAMP}-prompt-export-fout-CUIPER.log"
}

# ─── Extraheer berichten uit één sessie JSONL ─────────────────────────────────
extraheer_sessie() {
    local sessie_pad="$1"
    local sessie_id
    sessie_id=$(basename "$sessie_pad" .jsonl)

    python3 - "$sessie_pad" "$sessie_id" <<'PYEOF'
import json, sys

pad = sys.argv[1]
sessie_id = sys.argv[2]

msgs = []
with open(pad, "r") as f:
    for regel in f:
        regel = regel.strip()
        if not regel:
            continue
        try:
            obj = json.loads(regel)
        except Exception as e:
            print(json.dumps({"fout": str(e), "regel": regel[:100]}), file=sys.stderr)
            continue

        type_ = obj.get("type", "")
        is_summary = obj.get("isCompactSummary", False)
        ts = obj.get("timestamp", "")

        if type_ == "user":
            content = obj.get("message", {}).get("content", [])
            tekst = ""
            for blok in content:
                if isinstance(blok, dict) and blok.get("type") == "text":
                    t = blok.get("text", "").strip()
                    if (t and len(t) > 5
                            and "tool_use_id" not in t
                            and "system-reminder" not in t[:50]):
                        tekst += t + "\n"
            tekst = tekst.strip()
            if tekst:
                msgs.append({
                    "sessie": sessie_id,
                    "timestamp": ts,
                    "is_summary": is_summary,
                    "rol": "human",
                    "tekst": tekst
                })

        elif type_ == "assistant":
            content = obj.get("message", {}).get("content", [])
            tekst = ""
            for blok in content:
                if isinstance(blok, dict) and blok.get("type") == "text":
                    tekst += blok.get("text", "")
            tekst = tekst.strip()
            if tekst and len(tekst) > 10:
                msgs.append({
                    "sessie": sessie_id,
                    "timestamp": ts,
                    "is_summary": is_summary,
                    "rol": "assistant",
                    "tekst": tekst[:2000]  # eerste 2000 chars
                })

for m in msgs:
    print(json.dumps(m, ensure_ascii=False))
PYEOF
}

# ─── Verwerk alle sessies of één specifieke ───────────────────────────────────
TARGET_SESSIE=""
ALLE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sessie) TARGET_SESSIE="$2"; shift 2 ;;
        --alle)   ALLE=1; shift ;;
        *) log_fout "Onbekende optie: $1"; shift ;;
    esac
done

# Bepaal welke sessies te verwerken
drempel=1743552000  # 2 april 2026

if [[ -n "$TARGET_SESSIE" ]]; then
    sessies=("$CLAUDE_SESSIONS_DIR/${TARGET_SESSIE}.jsonl")
elif [[ $ALLE -eq 1 ]]; then
    # Geen -newer /dev/null hack — awk filtert op drempel, dat volstaat
    mapfile -t sessies < <(find "$CLAUDE_SESSIONS_DIR" -name "*.jsonl" \
        -exec stat -c "%Y %n" {} \; | awk -v d="$drempel" '$1 > d {print $2}' | sort)
else
    # Standaard: de nieuwste sessie — bash globbing ipv ls + /dev/null hack
    shopt -s nullglob
    _sessie_glob=("$CLAUDE_SESSIONS_DIR"/*.jsonl)
    shopt -u nullglob
    if [[ ${#_sessie_glob[@]} -eq 0 ]]; then
        log_fout "Geen .jsonl sessies gevonden in $CLAUDE_SESSIONS_DIR"
        exit 1
    fi
    sessies=("$(ls -t "${_sessie_glob[@]}" | head -1)")
fi

# ─── Export ──────────────────────────────────────────────────────────────────
uitvoer_jsonl="$PROMPTS_DIR/CuiperPrompts-$(date +%Y%m%d-%H%M%S).jsonl"
uitvoer_json="$PROMPTS_DIR/CuiperPrompts-$(date +%Y%m%d-%H%M%S).json"

alle_msgs=()

for sessie_pad in "${sessies[@]}"; do
    [[ -f "$sessie_pad" ]] || { log_fout "Sessie niet gevonden: $sessie_pad"; continue; }

    sessie_id=$(basename "$sessie_pad" .jsonl)
    echo "[INFO] Verwerk sessie: $sessie_id"

    while IFS= read -r regel; do
        [[ -n "$regel" ]] || continue
        echo "$regel" >> "$uitvoer_jsonl"
        alle_msgs+=("$regel")
    done < <(extraheer_sessie "$sessie_pad" 2>> "$CUIPER_TRAIL_DIR/${TIMESTAMP}-prompt-export-fout-CUIPER.log")
done

# JSON array schrijven
{
    echo "["
    n=${#alle_msgs[@]}
    for i in "${!alle_msgs[@]}"; do
        if [[ $i -lt $((n-1)) ]]; then
            echo "  ${alle_msgs[$i]},"
        else
            echo "  ${alle_msgs[$i]}"
        fi
    done
    echo "]"
} > "$uitvoer_json"

totaal="${#alle_msgs[@]}"
echo "[KLAAR] $totaal berichten geexporteerd"
echo "[KLAAR] JSONL: $uitvoer_jsonl"
echo "[KLAAR] JSON:  $uitvoer_json"

# ─── Genereer INSERT bestanden per databasetype ───────────────────────────────
# Elke message wordt getransformeerd naar het juiste INSERT formaat.
# Fout bij generatie → trail log, script gaat door met volgende formaat.

DATUMSTEMPEL=$(date +%Y%m%d-%H%M%S)
uitvoer_sql="$PROMPTS_DIR/CuiperPrompts-${DATUMSTEMPEL}.sql"
uitvoer_cypher="$PROMPTS_DIR/CuiperPrompts-${DATUMSTEMPEL}.cypher"
uitvoer_dl="$PROMPTS_DIR/CuiperPrompts-${DATUMSTEMPEL}.dl"
uitvoer_mongo="$PROMPTS_DIR/CuiperPrompts-${DATUMSTEMPEL}.mongo.js"

genereer_insert_bestanden() {
    python3 - "$uitvoer_jsonl" "$uitvoer_sql" "$uitvoer_cypher" "$uitvoer_dl" "$uitvoer_mongo" \
        "$TIMESTAMP" "$CUIPER_TRAIL_DIR" \
    <<'PYEOF'
import json, sys, os, time

jsonl_pad, sql_pad, cypher_pad, dl_pad, mongo_pad, ts, trail_dir = sys.argv[1:]
fout_log = os.path.join(trail_dir, f"{ts}-prompt-insert-fout-CUIPER.log")

msgs = []
with open(jsonl_pad, "r") as f:
    for regel in f:
        regel = regel.strip()
        if not regel:
            continue
        try:
            msgs.append(json.loads(regel))
        except Exception as e:
            with open(fout_log, "a") as fl:
                fl.write(f"[PARSE_FOUT] {e} — {regel[:80]}\n")

# ─── helpers ─────────────────────────────────────────────────────────────────

def q(s):
    """SQL string escaping — geen string interpolatie, geen injection."""
    if s is None:
        return "NULL"
    return "'" + str(s).replace("'", "''") + "'"

def q_cypher(s):
    """Cypher parameter string escaping."""
    if s is None:
        return '""'
    return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'

def q_dl(s):
    """Datalog symbol escaping."""
    if s is None:
        return '""'
    cleaned = str(s).replace('"', '\\"').replace('\n', ' ')[:200]
    return f'"{cleaned}"'

now_ms = int(time.time() * 1000)
branch = "claude/add-documentation-practices-cMBk1"

# ─── SQL INSERT (SQLite/DuckDB compatibel) ───────────────────────────────────

with open(sql_pad, "w") as f:
    f.write("-- CuiperPrompts INSERT — gegenereerd door CuiperPromptExporter.sh\n")
    f.write(f"-- Aangemaakt: {ts}\n")
    f.write("-- Laad via: sqlite3 cuiper.sqlite < dit_bestand.sql\n")
    f.write("--           duckdb cuiper.duckdb < dit_bestand.sql\n\n")
    f.write("BEGIN TRANSACTION;\n\n")

    for m in msgs:
        stap = m.get("cuiper_stap_nr") or 0
        sessie = m.get("sessie", "")
        tekst = m.get("tekst", "")
        bron = m.get("bron", "session-jsonl")
        unix_ms = now_ms
        if m.get("timestamp"):
            try:
                from datetime import datetime, timezone
                dt = datetime.fromisoformat(m["timestamp"].replace("Z", "+00:00"))
                unix_ms = int(dt.timestamp() * 1000)
            except Exception:
                pass

        rol = m.get("rol", "human")
        ulid_suffix = f"{stap:05d}{abs(hash(tekst[:20])) % 100000:05d}"
        ulid = f"01PRMPT{rol[:2].upper()}{ulid_suffix}"

        if rol == "human":
            f.write(
                f"INSERT OR IGNORE INTO cuiper_vraag_prompt "
                f"(ulid, cuiper_stap_nr, sessie_ulid, unix_ms, branch, hive_nr_van, hive_nr_naar, tekst, bron, aangemaakt) "
                f"VALUES ({q(ulid)}, {stap}, {q(sessie)}, {unix_ms}, {q(branch)}, 2, 3, {q(tekst)}, {q(bron)}, {now_ms});\n"
            )
        elif rol == "assistant":
            f.write(
                f"INSERT OR IGNORE INTO cuiper_antwoord_prompt "
                f"(ulid, vraag_ulid, cuiper_stap_nr, sessie_ulid, unix_ms, tekst, uitkomst, aangemaakt) "
                f"VALUES ({q(ulid)}, 'ONBEKEND-{stap}', {stap}, {q(sessie)}, {unix_ms}, {q(tekst[:1000])}, 'SUCCES', {now_ms});\n"
            )
    f.write("\nCOMMIT;\n")

# ─── Cypher MERGE (Neo4j) ─────────────────────────────────────────────────────

with open(cypher_pad, "w") as f:
    f.write("// CuiperPrompts Cypher MERGE — gegenereerd door CuiperPromptExporter.sh\n")
    f.write(f"// Aangemaakt: {ts}\n")
    f.write("// Laad via: cypher-shell --file dit_bestand.cypher\n\n")

    for m in msgs:
        stap = m.get("cuiper_stap_nr") or 0
        sessie = m.get("sessie", "")
        tekst = m.get("tekst", "")
        bron = m.get("bron", "session-jsonl")
        unix_ms = now_ms
        rol = m.get("rol", "human")
        ulid_suffix = f"{stap:05d}{abs(hash(tekst[:20])) % 100000:05d}"
        ulid = f"01PRMPT{rol[:2].upper()}{ulid_suffix}"

        if rol == "human":
            f.write(
                f"MERGE (v:CuiperVraagPrompt {{ulid: {q_cypher(ulid)}}})\n"
                f"ON CREATE SET v.cuiper_stap_nr={stap}, v.sessie_ulid={q_cypher(sessie)}, "
                f"v.unix_ms={unix_ms}, v.branch={q_cypher(branch)}, "
                f"v.tekst={q_cypher(tekst[:500])}, v.bron={q_cypher(bron)}, "
                f"v.aangemaakt={now_ms}\n"
                f"ON MATCH SET v._conflict=true;\n\n"
            )
        elif rol == "assistant":
            f.write(
                f"MERGE (a:CuiperAntwoordPrompt {{ulid: {q_cypher(ulid)}}})\n"
                f"ON CREATE SET a.cuiper_stap_nr={stap}, a.sessie_ulid={q_cypher(sessie)}, "
                f"a.unix_ms={unix_ms}, a.tekst={q_cypher(tekst[:500])}, "
                f"a.uitkomst=\"SUCCES\", a.aangemaakt={now_ms}\n"
                f"ON MATCH SET a._conflict=true;\n\n"
            )

# ─── Datalog feiten (.dl) ─────────────────────────────────────────────────────

with open(dl_pad, "w") as f:
    f.write("; CuiperPrompts Datalog feiten — gegenereerd door CuiperPromptExporter.sh\n")
    f.write(f"; Aangemaakt: {ts}\n")
    f.write("; Laad via: cuiper-datalog --facts dit_bestand.dl\n\n")

    for m in msgs:
        stap = m.get("cuiper_stap_nr") or 0
        sessie = m.get("sessie", "")
        tekst = m.get("tekst", "")
        bron = m.get("bron", "session-jsonl")
        rol = m.get("rol", "human")
        ulid_suffix = f"{stap:05d}{abs(hash(tekst[:20])) % 100000:05d}"
        ulid = f"01PRMPT{rol[:2].upper()}{ulid_suffix}"

        if rol == "human":
            f.write(
                f"vraag_prompt({q_dl(ulid)}, {stap}, {q_dl(sessie)}, "
                f"{now_ms}, {q_dl(branch)}, 2, {q_dl(tekst[:200])}, {q_dl(bron)}, {now_ms}).\n"
            )
        elif rol == "assistant":
            f.write(
                f"antwoord_prompt({q_dl(ulid)}, {q_dl('ONBEKEND-' + str(stap))}, "
                f'"",' f" {stap}, {q_dl(sessie)}, {now_ms}, "
                f"{q_dl(tekst[:200])}, \"SUCCES\", "
                f'"", "", "", "", "", {now_ms}).\n'
            )

# ─── MongoDB insertMany (.mongo.js) ──────────────────────────────────────────

with open(mongo_pad, "w") as f:
    f.write("// CuiperPrompts MongoDB insertMany — gegenereerd door CuiperPromptExporter.sh\n")
    f.write(f"// Aangemaakt: {ts}\n")
    f.write("// Laad via: mongosh cuiper_db --file dit_bestand.mongo.js\n\n")
    f.write("const db = db.getSiblingDB('cuiper_db');\n\n")

    vragen = []
    antwoorden = []

    for m in msgs:
        stap = m.get("cuiper_stap_nr") or 0
        sessie = m.get("sessie", "")
        tekst = m.get("tekst", "")
        bron = m.get("bron", "session-jsonl")
        rol = m.get("rol", "human")
        ulid_suffix = f"{stap:05d}{abs(hash(tekst[:20])) % 100000:05d}"
        ulid = f"01PRMPT{rol[:2].upper()}{ulid_suffix}"

        doc = {
            "ulid": ulid,
            "cuiper_stap_nr": stap,
            "sessie_ulid": sessie,
            "unix_ms": now_ms,
            "branch": branch,
            "tekst": tekst[:500],
            "bron": bron,
            "aangemaakt": now_ms
        }

        if rol == "human":
            doc["hive_nr_van"] = 2
            doc["hive_nr_naar"] = 3
            vragen.append(doc)
        elif rol == "assistant":
            doc["vraag_ulid"] = f"ONBEKEND-{stap}"
            doc["uitkomst"] = "SUCCES"
            antwoorden.append(doc)

    if vragen:
        f.write(f"db.cuiper_vraag_prompt.insertMany(\n{json.dumps(vragen, indent=2, ensure_ascii=False)},\n  {{ ordered: false }}\n);\n\n")
    if antwoorden:
        f.write(f"db.cuiper_antwoord_prompt.insertMany(\n{json.dumps(antwoorden, indent=2, ensure_ascii=False)},\n  {{ ordered: false }}\n);\n\n")

    f.write('print("[KLAAR] MongoDB inserts voltooid");\n')

print(f"[KLAAR] SQL:    {sql_pad}")
print(f"[KLAAR] Cypher: {cypher_pad}")
print(f"[KLAAR] DL:     {dl_pad}")
print(f"[KLAAR] Mongo:  {mongo_pad}")
PYEOF
}

genereer_insert_bestanden 2>> "$CUIPER_TRAIL_DIR/${TIMESTAMP}-prompt-insert-fout-CUIPER.log"
INSERT_EXIT=$?

if [[ $INSERT_EXIT -ne 0 ]]; then
    log_fout "genereer_insert_bestanden fout (exit=$INSERT_EXIT) — zie trail voor details"
fi

# Trail log
cat >> "$CUIPER_TRAIL_DIR/${TIMESTAMP}-prompt-export-CUIPER.log" <<EOF
CuiperPromptExporter — $(date -u +%Y-%m-%dT%H:%M:%SZ)
Sessies verwerkt: ${#sessies[@]}
Berichten: $totaal
JSONL:   $uitvoer_jsonl
JSON:    $uitvoer_json
SQL:     $uitvoer_sql
Cypher:  $uitvoer_cypher
DL:      $uitvoer_dl
Mongo:   $uitvoer_mongo
INSERT exit: $INSERT_EXIT
EOF
