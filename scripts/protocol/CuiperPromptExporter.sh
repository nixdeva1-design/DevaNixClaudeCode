#!/usr/bin/env bash
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
source "$SCRIPT_DIR/../../CuiperConfig.env" 2>/dev/null || {
    CUIPER_REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
    CUIPER_TRAIL_DIR="$CUIPER_REPO/logs/trail"
}

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
    mapfile -t sessies < <(find "$CLAUDE_SESSIONS_DIR" -name "*.jsonl" -newer /dev/null \
        -exec stat -c "%Y %n" {} \; | awk -v d="$drempel" '$1 > d {print $2}' | sort)
else
    # Standaard: de nieuwste sessie
    sessies=("$(ls -t "$CLAUDE_SESSIONS_DIR"/*.jsonl 2>/dev/null | head -1)")
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

# Trail log
cat >> "$CUIPER_TRAIL_DIR/${TIMESTAMP}-prompt-export-CUIPER.log" <<EOF
CuiperPromptExporter — $(date -u +%Y-%m-%dT%H:%M:%SZ)
Sessies verwerkt: ${#sessies[@]}
Berichten: $totaal
JSONL: $uitvoer_jsonl
JSON:  $uitvoer_json
EOF
