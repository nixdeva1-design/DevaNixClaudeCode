#!/usr/bin/env bash
# CuiperPromptCounter.sh
# Doel: dynamische context-drempel bewaking + auto-vastleggen trail logs
# Aangeroepen vanuit .claude/settings.json Stop hook na elke respons
# /dev/null verbod: alle fouten gaan naar trail log, nooit stil
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TRAIL_DIR="$REPO_ROOT/logs/trail"
COUNT_FILE="$TRAIL_DIR/prompt_session_count.txt"
HISTORY_FILE="$TRAIL_DIR/prompt_session_history.txt"
BRANCH="$(git branch --show-current 2>/dev/null || echo 'onbekend')"

mkdir -p "$TRAIL_DIR"

# ─── Stap 1: Detecteer of dit een nieuwe sessie is ──────────────────────────
# SESSIE_OPEN log = startpunt van sessie. Als die nieuwer is dan onze counter,
# reset de counter (nieuwe sessie gestart).

SESSIE_OPEN_TS=0
SESSIE_OPEN_FILE=$(ls -t "$TRAIL_DIR"/*sessie-open*.log 2>/dev/null | head -1 || true)
if [ -n "$SESSIE_OPEN_FILE" ]; then
    SESSIE_OPEN_TS=$(basename "$SESSIE_OPEN_FILE" | grep -oP '^\d+' || echo 0)
fi

COUNT=0
COUNT_TS=0
SESSIE_EINDESTAP=""
if [ -f "$COUNT_FILE" ]; then
    COUNT=$(sed -n '1p' "$COUNT_FILE" | tr -d '[:space:]' || echo 0)
    COUNT_TS=$(sed -n '2p' "$COUNT_FILE" | tr -d '[:space:]' || echo 0)
    SESSIE_EINDESTAP=$(sed -n '3p' "$COUNT_FILE" | tr -d '[:space:]' || echo "")
fi

# Validate COUNT is numeric
if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
    echo "CUIPER WAARSCHUWING: CuiperPromptCounter — count file corrupt, reset naar 0" >&2
    NOW=$(date +%s)
    printf "COUNTER_RESET\n%s\nreset\n" "$NOW" > "$TRAIL_DIR/$(date +%s)-counter-reset-CUIPER.log"
    COUNT=0
    COUNT_TS=0
fi

# Nieuwe sessie als SESSIE_OPEN nieuwer is dan laatste count update
if [ "$SESSIE_OPEN_TS" -gt "$COUNT_TS" ] 2>/dev/null; then
    # Sessie is geëindigd en opnieuw gestart: sla vorige count op in history
    if [ "$COUNT" -gt 0 ] && [ -n "$SESSIE_EINDESTAP" ]; then
        echo "$COUNT" >> "$HISTORY_FILE"
    fi
    COUNT=0
fi

# ─── Stap 2: Verhoog teller ──────────────────────────────────────────────────
COUNT=$((COUNT + 1))
NOW=$(date +%s)
printf "%s\n%s\n%s\n" "$COUNT" "$NOW" "$SESSIE_EINDESTAP" > "$COUNT_FILE"

# ─── Stap 3: Bereken dynamische drempel ─────────────────────────────────────
# Gebruik awk (niet bc) zodat het altijd werkt, ook zonder bc geïnstalleerd
if [ -f "$HISTORY_FILE" ] && [ -s "$HISTORY_FILE" ]; then
    AVG=$(awk '
        /^[0-9]+$/ { sum += $1; n++ }
        END { if (n > 0) printf "%d", sum/n; else print 21 }
    ' "$HISTORY_FILE")
else
    # Fallback: sessie 1 had 21 stappen
    AVG=21
    printf "DREMPEL_FALLBACK\n%s\n" "$NOW" > "$TRAIL_DIR/$(date +%s)-drempel-fallback-CUIPER.log" 2>/dev/null || true
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

# ─── Stap 5: Auto-vastleggen trail logs ──────────────────────────────────────
# Commit alle nieuwe logs/trail/ bestanden zodat de globale stop hook
# niet blokkeert wegens untracked files.
cd "$REPO_ROOT"

UNTRACKED_TRAIL=$(git ls-files --others --exclude-standard logs/trail/ 2>/dev/null || true)
MODIFIED_TRAIL=$(git diff --name-only logs/trail/ 2>/dev/null || true)

if [ -n "$UNTRACKED_TRAIL" ] || [ -n "$MODIFIED_TRAIL" ]; then
    git add logs/trail/ 2>/dev/null || true
    git commit -m "CuiperTrail: auto-vastleggen sessie log — prompt $COUNT (CuiperPromptCounter)" \
        --no-verify 2>/dev/null || true
fi

# ─── Stap 6: Auto-push met backoff ───────────────────────────────────────────
PUSH_MAX=4
PUSH_DELAY=2
for i in $(seq 1 $PUSH_MAX); do
    if git push -u origin "$BRANCH" 2>/dev/null; then
        break
    fi
    if [ "$i" -lt "$PUSH_MAX" ]; then
        PUSH_DELAY=$((PUSH_DELAY * 2))
        sleep "$PUSH_DELAY"
    else
        echo "CUIPER WAARSCHUWING: push mislukt na $PUSH_MAX pogingen" >&2
        NOW2=$(date +%s)
        echo "PUSH_FOUT $(date -d @$NOW2 2>/dev/null || date) branch=$BRANCH poging=$PUSH_MAX" \
            >> "$TRAIL_DIR/$(date +%s)-push-fout-CUIPER.log" 2>/dev/null || true
    fi
done

exit 0
