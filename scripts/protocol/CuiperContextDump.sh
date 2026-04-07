#!/usr/bin/env bash
# CuiperContextDump.sh — dump ClaudeCode context na elke CuiperStapNr
# Erft via: Cuiper → CuiperCore → CuiperDonut → CuiperZelfcontroleAI
#
# Gebruik:
#   bash CuiperContextDump.sh <ulid> <stap_nr> "<huidige_taak>" [<huidige_taak_ulid>]
#
# Schrijft naar:
#   logs/context/ClaudeCodeContext.md    (append, mensleesbaar)
#   logs/context/ClaudeCodeContext.jsonl (append, machineleesbaar, één record per stap)
#
# Redundantie: toegestaan. Elke stap = unieke ULID + StapNr.
# Data lake model: nooit verwijderen, altijd aanvullen.
# Recursie scope: Cuiper=1 is het anker. Max diepte: 10.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../CuiperConfig.env" 2>/dev/null || {
    CUIPER_REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
    CUIPER_TRAIL_DIR="$CUIPER_REPO/logs/trail"
    CUIPER_BACKLOG_DIR="$CUIPER_REPO/backlog"
}

CONTEXT_DIR="$CUIPER_REPO/logs/context"
CONTEXT_MD="$CONTEXT_DIR/ClaudeCodeContext.md"
CONTEXT_JSONL="$CONTEXT_DIR/ClaudeCodeContext.jsonl"
BACKLOG_FILE="$CUIPER_BACKLOG_DIR/CuiperBacklog.md"

mkdir -p "$CONTEXT_DIR"

log_fout() {
    echo "[FOUT] $*" >&2
    echo "[FOUT] $(date +%s) $*" >> "$CUIPER_TRAIL_DIR/$(date +%s)-context-fout-CUIPER.log"
}

# ─── Args ─────────────────────────────────────────────────────────────────────
ULID="${1:-ONBEKEND}"
STAP_NR="${2:-0}"
HUIDIGE_TAAK="${3:-onbekend}"
HUIDIGE_TAAK_ULID="${4:-}"

# ─── Systeemdata ophalen ───────────────────────────────────────────────────────
UNIX_MS=$(date +%s%3N)
UNIX_S=$(date +%s)
BRANCH=$(git -C "$CUIPER_REPO" branch --show-current 2>/dev/null || echo "onbekend")
LAATSTE_COMMIT=$(git -C "$CUIPER_REPO" log --oneline -1 2>/dev/null || echo "geen")
COMMIT_HASH=$(echo "$LAATSTE_COMMIT" | awk '{print $1}')
COMMIT_MSG=$(echo "$LAATSTE_COMMIT" | cut -d' ' -f2-)

# Backlog tellingen
OPEN_KRITIEK=$(grep -c "| OPEN.*KRITIEK\|BEZIG.*KRITIEK" "$BACKLOG_FILE" 2>/dev/null || true); OPEN_KRITIEK="${OPEN_KRITIEK:-0}"
OPEN_HOOG=$(grep -c "| OPEN.*HOOG\|BEZIG.*HOOG" "$BACKLOG_FILE" 2>/dev/null || true); OPEN_HOOG="${OPEN_HOOG:-0}"
OPEN_MEDIUM=$(grep -c "| OPEN.*MEDIUM\|BEZIG.*MEDIUM" "$BACKLOG_FILE" 2>/dev/null || true); OPEN_MEDIUM="${OPEN_MEDIUM:-0}"
OPEN_LAAG=$(grep -c "| OPEN.*LAAG\|BEZIG.*LAAG" "$BACKLOG_FILE" 2>/dev/null || true); OPEN_LAAG="${OPEN_LAAG:-0}"
WEES_N=$(grep -c "| WEES " "$BACKLOG_FILE" 2>/dev/null || true); WEES_N="${WEES_N:-0}"
KLAAR_N=$(grep -c "| KLAAR " "$BACKLOG_FILE" 2>/dev/null || true); KLAAR_N="${KLAAR_N:-0}"

# Context status uit prompt counter
CONTEXT_STATUS="OK"
if [[ -f "$CUIPER_TRAIL_DIR/prompt_session_count.txt" ]]; then
    COUNT=$(head -1 "$CUIPER_TRAIL_DIR/prompt_session_count.txt" 2>/dev/null | tr -d '[:space:]' || echo 0)
    COUNT="${COUNT:-0}"
    HISTORY_FILE="$CUIPER_TRAIL_DIR/prompt_session_history.txt"
    if [[ -f "$HISTORY_FILE" ]]; then
        AVG=$(awk '{s+=$1;n++} END{print (n>0?s/n:21)}' "$HISTORY_FILE" 2>/dev/null || echo 21)
        DREMPEL_ZACHT=$(awk "BEGIN{printf \"%d\", $AVG * 0.80}")
        DREMPEL_HARD=$(awk "BEGIN{printf \"%d\", $AVG * 0.95}")
        if [[ "$COUNT" -ge "$DREMPEL_HARD" ]]; then
            CONTEXT_STATUS="DREMPEL_HARD"
        elif [[ "$COUNT" -ge "$DREMPEL_ZACHT" ]]; then
            CONTEXT_STATUS="DREMPEL_ZACHT"
        fi
    fi
    PROMPT_NR="$COUNT"
else
    PROMPT_NR=0
fi

# Vorige stap ULID (laatste regel in JSONL)
VORIGE_ULID="null"
if [[ -f "$CONTEXT_JSONL" ]]; then
    LAATSTE_REGEL=$(tail -1 "$CONTEXT_JSONL" 2>/dev/null || echo "")
    if [[ -n "$LAATSTE_REGEL" ]]; then
        VORIGE_ULID=$(echo "$LAATSTE_REGEL" | python3 -c \
            "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('ulid','null'))" \
            2>/dev/null || echo "null")
    fi
fi

# Recente trail logs
RECENTE_TRAIL=$(ls -t "$CUIPER_TRAIL_DIR"/*.log 2>/dev/null | head -3 | xargs -I{} basename {} 2>/dev/null | tr '\n' ',' | sed 's/,$//' || echo "geen")

# ─── MD schrijven (append) ────────────────────────────────────────────────────
cat >> "$CONTEXT_MD" <<MDEOF

---
## CuiperStapNr: ${STAP_NR} | ULID: ${ULID}
**Datum:** $(date -u +%Y-%m-%dT%H:%M:%SZ) | **Branch:** ${BRANCH}

| Veld | Waarde |
|------|--------|
| Huidige taak | ${HUIDIGE_TAAK} |
| Taak ULID | ${HUIDIGE_TAAK_ULID:-—} |
| Commit | ${COMMIT_HASH} — ${COMMIT_MSG:0:60} |
| Context status | ${CONTEXT_STATUS} |
| Prompt nr | ${PROMPT_NR} |
| Vorige stap | ${VORIGE_ULID} |

**Backlog:** KRITIEK:${OPEN_KRITIEK} HOOG:${OPEN_HOOG} MEDIUM:${OPEN_MEDIUM} LAAG:${OPEN_LAAG} WEES:${WEES_N} KLAAR:${KLAAR_N}

**Recente trail logs:** ${RECENTE_TRAIL}

**Recursie scope:** Cuiper=Anker. Max diepte: 10. (Von Neumann serieel model — toekomstige uitvinding buiten scope.)

MDEOF

# ─── JSONL schrijven (append, één record per stap) ───────────────────────────
# Gebruik python3 -c met env-variabelen om bash heredoc interpolatie te vermijden
VORIGE_JSON=$( [ "$VORIGE_ULID" = "null" ] && echo "null" || echo "\"$VORIGE_ULID\"" )
PROMPT_NR_CLEAN=$(echo "${PROMPT_NR:-0}" | tr -d '[:space:]' | grep -o '^[0-9]*' || echo 0)

ULID_E="$ULID" STAP_NR_E="$STAP_NR" UNIX_MS_E="$UNIX_MS" BRANCH_E="$BRANCH" \
HUIDIGE_TAAK_E="$HUIDIGE_TAAK" HUIDIGE_TAAK_ULID_E="${HUIDIGE_TAAK_ULID:-}" \
CONTEXT_STATUS_E="$CONTEXT_STATUS" PROMPT_NR_CLEAN_E="${PROMPT_NR_CLEAN:-0}" \
OPEN_KRITIEK_E="${OPEN_KRITIEK:-0}" OPEN_HOOG_E="${OPEN_HOOG:-0}" \
OPEN_MEDIUM_E="${OPEN_MEDIUM:-0}" OPEN_LAAG_E="${OPEN_LAAG:-0}" \
WEES_N_E="${WEES_N:-0}" KLAAR_N_E="${KLAAR_N:-0}" \
COMMIT_HASH_E="${COMMIT_HASH:-}" COMMIT_MSG_E="${COMMIT_MSG:-}" \
VORIGE_ULID_E="$VORIGE_ULID" UNIX_S_E="$UNIX_S" \
python3 -c "
import json, os
record = {
    'ulid':              os.environ['ULID_E'],
    'cuiper_stap_nr':    int(os.environ['STAP_NR_E']),
    'unix_ms':           int(os.environ['UNIX_MS_E']),
    'branch':            os.environ['BRANCH_E'],
    'huidige_taak':      os.environ['HUIDIGE_TAAK_E'],
    'huidige_taak_ulid': os.environ.get('HUIDIGE_TAAK_ULID_E', ''),
    'context_status':    os.environ['CONTEXT_STATUS_E'],
    'prompt_nr':         int(os.environ.get('PROMPT_NR_CLEAN_E', '0') or '0'),
    'backlog': {
        'kritiek': int(os.environ.get('OPEN_KRITIEK_E', '0') or '0'),
        'hoog':    int(os.environ.get('OPEN_HOOG_E',    '0') or '0'),
        'medium':  int(os.environ.get('OPEN_MEDIUM_E',  '0') or '0'),
        'laag':    int(os.environ.get('OPEN_LAAG_E',    '0') or '0'),
        'wees':    int(os.environ.get('WEES_N_E',       '0') or '0'),
        'klaar':   int(os.environ.get('KLAAR_N_E',      '0') or '0'),
    },
    'commit_hash':       os.environ.get('COMMIT_HASH_E', ''),
    'commit_msg':        os.environ.get('COMMIT_MSG_E',  ''),
    'vorige_stap_ulid':  None if os.environ['VORIGE_ULID_E'] == 'null' else os.environ['VORIGE_ULID_E'],
    'recursie_diepte':   0,
    'recursie_anker':    'Cuiper=1',
    'aangemaakt':        int(os.environ['UNIX_S_E']),
}
print(json.dumps(record, ensure_ascii=False))
" >> "$CONTEXT_JSONL"

echo "[CONTEXT] StapNr=${STAP_NR} ULID=${ULID} gedumpt → ${CONTEXT_JSONL}"
