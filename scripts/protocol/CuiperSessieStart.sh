#!/usr/bin/env bash
# CuiperSessieStart.sh — PreToolUse hook
# Schrijft SESSIE_OPEN log + verhoogt CuiperSessieNr bij nieuwe sessie
# Erft via: Cuiper → CuiperCore → CuiperDonut → CuiperSessieStartOperator
#
# Detectie: als geen SESSIE_OPEN log bestaat van de huidige minuut,
# is dit een nieuwe sessie.

set -euo pipefail

# ─── CuiperModuleLib ─────────────────────────────────────────────────────────
_CUIPER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/protocol/CuiperModuleLib.sh
source "${_CUIPER_LIB_DIR}/CuiperModuleLib.sh" 2>/dev/null || true
CUIPER_MODULE_NAAM="CuiperSessieStart"
CUIPER_MODULE_VERSIE="0.2.0"
CUIPER_IN="hook"
CUIPER_OUT="trail,file"
CUIPER_MODULE_OMSCHRIJVING="PreToolUse hook: schrijft SESSIE_OPEN log en verhoogt CuiperSessieNr"
CUIPER_MODULE_WERKING="Detecteert nieuwe sessie via COUNT_TS delta > 300s. Reset teller."
cuiper_init_flags "$@"
# ─────────────────────────────────────────────────────────────────────────────


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../CuiperConfig.env" 2>/dev/null || {
    CUIPER_REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$HOME/DevaNixClaudeCode")"
    CUIPER_TRAIL_DIR="$CUIPER_REPO/logs/trail"
}

NOW=$(date +%s)
SESSIE_NR_FILE="$CUIPER_TRAIL_DIR/CuiperSessieNr.txt"
COUNT_FILE="$CUIPER_TRAIL_DIR/prompt_session_count.txt"

mkdir -p "$CUIPER_TRAIL_DIR"

# Lees huidige COUNT_TS (timestamp van laatste stop-hook run)
COUNT_TS=0
if [[ -f "$COUNT_FILE" ]]; then
    COUNT_TS=$(sed -n '2p' "$COUNT_FILE" 2>/dev/null | tr -d '[:space:]' || echo 0)
    COUNT_TS="${COUNT_TS:-0}"
fi

# Nieuwe sessie als COUNT_TS ouder is dan 5 minuten (300s)
# Dit vangt nieuwe Claude Code sessies op zonder expliciete sessie-UUID
DELTA=$(( NOW - COUNT_TS ))
if [[ "$DELTA" -gt 300 ]] || [[ "$COUNT_TS" -eq 0 ]]; then
    # Nieuwe sessie gedetecteerd

    # Verhoog SessieNr
    HUIDIG_NR=0
    if [[ -f "$SESSIE_NR_FILE" ]]; then
        HUIDIG_NR=$(head -1 "$SESSIE_NR_FILE" 2>/dev/null | tr -d '[:space:]' || echo 0)
        HUIDIG_NR="${HUIDIG_NR:-0}"
    fi
    NIEUW_NR=$(( HUIDIG_NR + 1 ))

    # Genereer ULID-achtige sessie ID
    SESSIE_ULID="01SESSIE$(cat /dev/urandom | tr -dc 'A-Z0-9' | head -c 16 2>/dev/null || echo "NIEUW${NOW}")"

    # Schrijf SessieNr file
    printf "%s\n%s\n%s\n" "$NIEUW_NR" "$NOW" "$SESSIE_ULID" > "$SESSIE_NR_FILE"

    # Schrijf SESSIE_OPEN log (dit is wat CuiperPromptCounter.sh detecteert)
    SESSIE_LOG="$CUIPER_TRAIL_DIR/${NOW}-sessie-open-${SESSIE_ULID}.log"
    printf "CuiperSessieNr: %s\nULID: %s\nTimestamp: %s\n" \
        "$NIEUW_NR" "$SESSIE_ULID" "$NOW" > "$SESSIE_LOG"

    # Reset prompt counter voor nieuwe sessie
    printf "0\n%s\n\n" "$NOW" > "$COUNT_FILE"

    # Sedimenteer in context dump
    CONTEXT_JSONL="$CUIPER_REPO/logs/context/ClaudeCodeContext.jsonl"
    if [[ -f "$CONTEXT_JSONL" ]]; then
        python3 -c "
import json, os
record = {
    'type': 'SESSIE_START',
    'sessie_nr': int(os.environ.get('NIEUW_NR','0')),
    'sessie_ulid': os.environ.get('SESSIE_ULID',''),
    'unix_ms': int(os.environ.get('NOW','0')) * 1000,
    'vorige_delta_seconden': int(os.environ.get('DELTA','0'))
}
print(json.dumps(record, ensure_ascii=False))
" >> "$CONTEXT_JSONL" 2>/dev/null || true
    fi
fi

exit 0
