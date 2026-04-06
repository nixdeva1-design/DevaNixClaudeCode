#!/usr/bin/env bash
# CuiperPromptCounter.sh
# Doel: dynamische context-drempel bewaking + auto-vastleggen trail logs
# Aangeroepen vanuit .claude/settings.json Stop hook na elke respons
# /dev/null verbod: ALLE fouten gaan naar trail log, nooit stil
set -uo pipefail

# ─── Hulpfunctie: log fout naar trail, nooit naar /dev/null ──────────────────
log_fout() {
    local CONTEXT="$1"
    local BERICHT="$2"
    local LOGBESTAND="${TRAIL_DIR:-/tmp}/$(date +%s)-fout-${CONTEXT}-CUIPER.log"
    printf "%s FOUT [%s]: %s\n" "$(date +%s)" "$CONTEXT" "$BERICHT" >> "$LOGBESTAND"
    echo "CUIPER FOUT [$CONTEXT]: $BERICHT" >&2
}

# ─── Repo root bepalen — fout is informatie ──────────────────────────────────
REPO_ROOT_ERR=""
if ! REPO_ROOT=$(git rev-parse --show-toplevel 2>&1); then
    REPO_ROOT_ERR="$REPO_ROOT"
    REPO_ROOT="$(pwd)"
    printf "%s REPO_FOUT: git rev-parse mislukt: %s\n" "$(date +%s)" "$REPO_ROOT_ERR" \
        >> "/tmp/cuiper-repo-fout-$(date +%s).log"
fi

TRAIL_DIR="$REPO_ROOT/logs/trail"
COUNT_FILE="$TRAIL_DIR/prompt_session_count.txt"
HISTORY_FILE="$TRAIL_DIR/prompt_session_history.txt"

BRANCH_ERR=""
if ! BRANCH=$(git branch --show-current 2>&1); then
    BRANCH_ERR="$BRANCH"
    BRANCH="onbekend"
    log_fout "BRANCH" "git branch --show-current mislukt: $BRANCH_ERR"
fi

mkdir -p "$TRAIL_DIR"

# ─── Stap 1: Detecteer of dit een nieuwe sessie is ──────────────────────────
SESSIE_OPEN_TS=0
SESSIE_OPEN_FILE=""
SESSIE_OPEN_ERR=""
if ! SESSIE_OPEN_FILE=$(ls -t "$TRAIL_DIR"/*sessie-open*.log 2>&1 | head -1); then
    SESSIE_OPEN_ERR="$SESSIE_OPEN_FILE"
    SESSIE_OPEN_FILE=""
    log_fout "SESSIE_OPEN" "geen sessie-open log gevonden: $SESSIE_OPEN_ERR"
fi

if [ -n "$SESSIE_OPEN_FILE" ] && [ -f "$SESSIE_OPEN_FILE" ]; then
    SESSIE_OPEN_TS=$(basename "$SESSIE_OPEN_FILE" | grep -oP '^\d+' || echo 0)
fi

COUNT=0
COUNT_TS=0
SESSIE_EINDESTAP=""
if [ -f "$COUNT_FILE" ]; then
    COUNT=$(sed -n '1p' "$COUNT_FILE" | tr -d '[:space:]') || COUNT=0
    COUNT_TS=$(sed -n '2p' "$COUNT_FILE" | tr -d '[:space:]') || COUNT_TS=0
    SESSIE_EINDESTAP=$(sed -n '3p' "$COUNT_FILE" | tr -d '[:space:]') || SESSIE_EINDESTAP=""
fi

# Valideer: COUNT moet een getal zijn
if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
    CORRUPT_LOG="$TRAIL_DIR/$(date +%s)-counter-reset-CUIPER.log"
    printf "%s COUNTER_RESET: count file corrupt was '%s', reset naar 0\n" \
        "$(date +%s)" "$COUNT" >> "$CORRUPT_LOG"
    echo "CUIPER WAARSCHUWING: count file corrupt ('$COUNT'), reset naar 0" >&2
    COUNT=0
    COUNT_TS=0
fi

# Nieuwe sessie: SESSIE_OPEN nieuwer dan laatste count timestamp
if [ "${SESSIE_OPEN_TS:-0}" -gt "${COUNT_TS:-0}" ] 2>&1 | grep -q "" || \
   [ "${SESSIE_OPEN_TS:-0}" -gt "${COUNT_TS:-0}" ]; then
    if [ "$COUNT" -gt 0 ] && [ -n "$SESSIE_EINDESTAP" ]; then
        echo "$COUNT" >> "$HISTORY_FILE"
        log_fout "SESSIE_HIST" "sessie van $COUNT prompts opgeslagen in history" 2>/dev/null || \
            printf "%s SESSIE_HIST: %s prompts opgeslagen\n" "$(date +%s)" "$COUNT" \
            >> "$TRAIL_DIR/$(date +%s)-sessie-hist-CUIPER.log"
    fi
    COUNT=0
fi

# ─── Stap 2: Verhoog teller ──────────────────────────────────────────────────
COUNT=$((COUNT + 1))
NOW=$(date +%s)
printf "%s\n%s\n%s\n" "$COUNT" "$NOW" "$SESSIE_EINDESTAP" > "$COUNT_FILE"

# ─── Stap 3: Bereken dynamische drempel — awk, nooit bc ─────────────────────
if [ -f "$HISTORY_FILE" ] && [ -s "$HISTORY_FILE" ]; then
    AVG=$(awk '/^[0-9]+$/ { sum += $1; n++ } END { if (n > 0) printf "%d", sum/n; else print 21 }' \
        "$HISTORY_FILE")
else
    AVG=21
    printf "%s DREMPEL_FALLBACK: geen history, gebruik AVG=21\n" "$NOW" \
        >> "$TRAIL_DIR/$(date +%s)-drempel-fallback-CUIPER.log"
fi

DREMPEL_ZACHT=$(awk "BEGIN { printf \"%d\", $AVG * 0.80 }")
DREMPEL_HARD=$(awk "BEGIN { printf \"%d\", $AVG * 0.95 }")

# ─── Stap 4: Waarschuwingen ──────────────────────────────────────────────────
if [ "$COUNT" -ge "$DREMPEL_HARD" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    echo "CUIPER CONTEXT KRITIEK: prompt $COUNT/$DREMPEL_HARD (avg=$AVG)" >&2
    echo "Context limiet NABIJ. Verplicht: plan sessie-einde, push alles." >&2
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
    exit 2
elif [ "$COUNT" -ge "$DREMPEL_ZACHT" ]; then
    echo "CUIPER CONTEXT WAARSCHUWING: prompt $COUNT/$DREMPEL_ZACHT (avg=$AVG) — context limiet nadert." >&2
fi

# ─── Stap 4b: Jaeger span voor deze prompt ───────────────────────────────────
# Elke prompt = een span in Jaeger, zichtbaar in de UI
_COUNTER_SPAN_START=$(date +%s)
_COUNTER_SPAN_ID=$(cat /dev/urandom | tr -dc '0-9a-f' | head -c 16 2>/dev/null || \
    printf '%016x' $((RANDOM * RANDOM)))
_COUNTER_TRACE_ID=$(cat /dev/urandom | tr -dc '0-9a-f' | head -c 32 2>/dev/null || \
    printf '%032x' $((RANDOM * RANDOM * RANDOM)))
_COUNTER_STATUS=1
[ "$COUNT" -ge "$DREMPEL_HARD" ] && _COUNTER_STATUS=2

JAEGER_ERR=""
if ! JAEGER_ERR=$(bash "$(dirname "${BASH_SOURCE[0]}")/CuiperJaegerSpan.sh" \
    --trace "$_COUNTER_TRACE_ID" \
    --span  "$_COUNTER_SPAN_ID" \
    --naam  "CuiperPromptCounter prompt $COUNT" \
    --start "$_COUNTER_SPAN_START" \
    --eind  "$(date +%s)" \
    --status "$_COUNTER_STATUS" \
    --stap  "$COUNT" \
    --exit  0 2>&1); then
    log_fout "JAEGER_COUNTER" "$JAEGER_ERR"
fi

# ─── Stap 5: Auto-vastleggen trail logs ──────────────────────────────────────
cd "$REPO_ROOT"

UNTRACKED_ERR=""
UNTRACKED_TRAIL=""
if ! UNTRACKED_TRAIL=$(git ls-files --others --exclude-standard logs/trail/ 2>&1); then
    UNTRACKED_ERR="$UNTRACKED_TRAIL"
    UNTRACKED_TRAIL=""
    log_fout "GIT_UNTRACKED" "$UNTRACKED_ERR"
fi

MODIFIED_ERR=""
MODIFIED_TRAIL=""
if ! MODIFIED_TRAIL=$(git diff --name-only logs/trail/ 2>&1); then
    MODIFIED_ERR="$MODIFIED_TRAIL"
    MODIFIED_TRAIL=""
    log_fout "GIT_DIFF" "$MODIFIED_ERR"
fi

if [ -n "$UNTRACKED_TRAIL" ] || [ -n "$MODIFIED_TRAIL" ]; then
    ADD_ERR=""
    if ! ADD_ERR=$(git add logs/trail/ 2>&1); then
        log_fout "GIT_ADD" "$ADD_ERR"
    fi

    COMMIT_ERR=""
    if ! COMMIT_ERR=$(git commit \
        -m "CuiperTrail: auto-vastleggen sessie log — prompt $COUNT (CuiperPromptCounter)" \
        --no-verify 2>&1); then
        log_fout "GIT_COMMIT" "$COMMIT_ERR"
    fi
fi

# ─── Stap 6: Auto-push met backoff ───────────────────────────────────────────
PUSH_MAX=4
PUSH_DELAY=2
PUSH_ERR=""
for i in $(seq 1 $PUSH_MAX); do
    if PUSH_ERR=$(git push -u origin "$BRANCH" 2>&1); then
        PUSH_ERR=""
        break
    fi
    if [ "$i" -lt "$PUSH_MAX" ]; then
        PUSH_DELAY=$((PUSH_DELAY * 2))
        sleep "$PUSH_DELAY"
    else
        FOUT_LOG="$TRAIL_DIR/$(date +%s)-push-fout-CUIPER.log"
        printf "%s PUSH_FOUT branch=%s poging=%s:\n%s\n" \
            "$(date +%s)" "$BRANCH" "$PUSH_MAX" "$PUSH_ERR" >> "$FOUT_LOG"
        echo "CUIPER WAARSCHUWING: push mislukt na $PUSH_MAX pogingen — zie $FOUT_LOG" >&2
    fi
done

exit 0
