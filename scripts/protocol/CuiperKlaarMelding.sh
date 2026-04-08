#!/usr/bin/env bash

# ─── CuiperHeader ───────────────────────────────────────────────────────────
# ULID:          01COMP003KLAAR00000000000
# Naam:          scripts/protocol/CuiperKlaarMelding.sh
# Erft via:      CuiperCore → CuiperDonut → CuiperClaudeCodeTakenlijst → CuiperKlaarMeldingOperator
# Aangemaakt:    CuiperStapNr 32
# Gewijzigd:     CuiperStapNr 54 — 2026-04-08
# ────────────────────────────────────────────────────────────────────────────

# CuiperKlaarMelding.sh
# Doel: verplichte klaar-melding aan het einde van elke ClaudeCode respons
# Toont: CuiperStapNr, sessie voortgang, backlog samenvatting, prioriteit hulp
# /dev/null verbod: alle fouten naar trail, nooit stil
#
# Gebruik: bash scripts/protocol/CuiperKlaarMelding.sh [ulid] [stapnr]
set -uo pipefail

REPO_ROOT_ERR=""
if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>&1); then
    REPO_ROOT_ERR="$REPO_ROOT"
    REPO_ROOT="$(pwd)"
    echo "CUIPER FOUT [KLAAR_REPO]: $REPO_ROOT_ERR" >&2
fi

TRAIL_DIR="$REPO_ROOT/logs/trail"
COUNT_FILE="$TRAIL_DIR/prompt_session_count.txt"
HISTORY_FILE="$TRAIL_DIR/prompt_session_history.txt"
BACKLOG_SCRIPT="$REPO_ROOT/scripts/protocol/CuiperBacklogPlanner.sh"

ULID="${1:-onbekend}"
STAPNR="${2:-?}"

# ─── Lees sessie counter ─────────────────────────────────────────────────────
COUNT=0
DREMPEL_ZACHT=17
DREMPEL_HARD=20

if [ -f "$COUNT_FILE" ]; then
    COUNT=$(sed -n '1p' "$COUNT_FILE" | tr -d '[:space:]') || COUNT=0
fi

if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
    COUNT=0
fi

if [ -f "$HISTORY_FILE" ] && [ -s "$HISTORY_FILE" ]; then
    AVG=$(awk '/^[0-9]+$/ { sum += $1; n++ } END { if (n > 0) printf "%d", sum/n; else print 21 }' \
        "$HISTORY_FILE")
else
    AVG=21
fi
DREMPEL_ZACHT=$(awk "BEGIN { printf \"%d\", $AVG * 0.80 }")
DREMPEL_HARD=$(awk "BEGIN { printf \"%d\", $AVG * 0.95 }")

# ─── Context status label ────────────────────────────────────────────────────
if [ "$COUNT" -ge "$DREMPEL_HARD" ]; then
    CTX_STATUS="KRITIEK — plan sessie-einde"
elif [ "$COUNT" -ge "$DREMPEL_ZACHT" ]; then
    CTX_STATUS="WAARSCHUWING — context nadert limiet"
else
    RESTEREND=$(( DREMPEL_ZACHT - COUNT ))
    CTX_STATUS="OK (nog ~${RESTEREND} prompts voor zachte drempel)"
fi

# ─── Haal laatste commit op ──────────────────────────────────────────────────
COMMIT_HASH=""
COMMIT_ERR=""
if ! COMMIT_HASH=$(git rev-parse --short HEAD 2>&1); then
    COMMIT_ERR="$COMMIT_HASH"
    COMMIT_HASH="onbekend"
    printf "%s GIT_HEAD_FOUT: %s\n" "$(date +%s)" "$COMMIT_ERR" \
        >> "$TRAIL_DIR/$(date +%s)-klaar-fout-CUIPER.log"
fi

BRANCH_ERR=""
if ! BRANCH=$(git branch --show-current 2>&1); then
    BRANCH_ERR="$BRANCH"
    BRANCH="onbekend"
    printf "%s BRANCH_FOUT: %s\n" "$(date +%s)" "$BRANCH_ERR" \
        >> "$TRAIL_DIR/$(date +%s)-klaar-fout-CUIPER.log"
fi

# ─── Backlog samenvatting ────────────────────────────────────────────────────
BACKLOG_SAM="  (backlog script niet gevonden)"
if [ -x "$BACKLOG_SCRIPT" ]; then
    BACKLOG_ERR=""
    if ! BACKLOG_SAM=$(bash "$BACKLOG_SCRIPT" samenvatting 2>&1); then
        BACKLOG_ERR="$BACKLOG_SAM"
        BACKLOG_SAM="  (fout bij lezen backlog)"
        printf "%s BACKLOG_FOUT: %s\n" "$(date +%s)" "$BACKLOG_ERR" \
            >> "$TRAIL_DIR/$(date +%s)-klaar-fout-CUIPER.log"
    fi
fi

# ─── Uitvoer ──────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CUIPER KLAAR MELDING"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Lees CuiperSessieNr
SESSIE_NR_FILE="$TRAIL_DIR/CuiperSessieNr.txt"
SESSIE_NR=$(head -1 "$SESSIE_NR_FILE" 2>/dev/null | tr -d '[:space:]' || echo "?")
SESSIE_ULID=$(sed -n '3p' "$SESSIE_NR_FILE" 2>/dev/null | tr -d '[:space:]' || echo "")
printf "  CuiperStapNr:  %s\n"      "$STAPNR"
printf "  CuiperSessieNr:%s\n"      "${SESSIE_NR:-?}"
printf "  ULID:          %s\n"      "$ULID"
printf "  Commit:        %s\n"      "$COMMIT_HASH"
printf "  Branch:        %s\n"      "$BRANCH"
printf "  Sessie prompt: %s/%s     Context: %s\n" "$COUNT" "$DREMPEL_ZACHT" "$CTX_STATUS"
echo ""
echo "  Backlog:"
echo "$BACKLOG_SAM"
echo ""
echo "  Prioriteit wijzigen:"
echo "    scripts/protocol/CuiperBacklogPlanner.sh prioriteit <id> <KRITIEK|HOOG|MEDIUM|LAAG>"
echo "  Status wijzigen:"
echo "    scripts/protocol/CuiperBacklogPlanner.sh status <id> <OPEN|BEZIG|KLAAR|GEBLOKKEERD>"
echo "  Volledig overzicht:"
echo "    scripts/protocol/CuiperBacklogPlanner.sh toon"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
