#!/usr/bin/env bash

# ─── CuiperHeader ───────────────────────────────────────────────────────────
# ULID:          01COMP001LISTENER000000000
# Naam:          scripts/protocol/CuiperListener.sh
# Erft via:      CuiperCore → CuiperDonut
# Aangemaakt:    CuiperStapNr 34
# Gewijzigd:     CuiperStapNr 54 — 2026-04-08
# ────────────────────────────────────────────────────────────────────────────

# CuiperListener.sh — uitvoeringsomgeving voor alle CuiperHive code
#
# Taken:
#   1. Voer het opgegeven commando uit (nooit direct — altijd via de listener)
#   2. Vang stdout én stderr op — /dev/null verbod
#   3. Stuur een Jaeger/OTLP trace span voor elke uitvoering
#   4. Log output + exit code naar logs/trail/
#   5. Geef de exit code van het originele commando terug
#
# Gebruik:
#   bash CuiperListener.sh --exec "bash mijn_script.sh" --naam "mijn_script" --stap 34
#   bash CuiperListener.sh --exec "cargo test" --naam "cuiper-core tests" --stap 34
#
# /dev/null verbod: elke byte output wordt gesedimenteerd
#
# Cuip: 01KNLISTENER | SESSIE | L:1 | "CuiperListener bootstrap"

set -uo pipefail

# ─── Centrale config ─────────────────────────────────────────────────────────
_LISTENER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LISTENER_DIR/../../CuiperConfig.env"

TRAIL_DIR="$CUIPER_TRAIL_DIR"
mkdir -p "$TRAIL_DIR"

# ─── ULID helper ─────────────────────────────────────────────────────────────
ulid() {
    local ENC="0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    local ts n t r
    ts=$(date +%s%3N); n=$ts; t=""
    for i in $(seq 1 10); do t="${ENC:$((n%32)):1}${t}"; n=$((n/32)); done
    r=""
    for i in $(seq 1 16); do r="${r}${ENC:$((RANDOM%32)):1}"; done
    echo "${t}${r}"
}

# ─── Log fout naar trail — nooit stil ────────────────────────────────────────
log_fout() {
    local CONTEXT="$1"
    local BERICHT="$2"
    printf "%s FOUT [%s]: %s\n" "$(date +%s)" "$CONTEXT" "$BERICHT" \
        >> "$TRAIL_DIR/$(date +%s)-listener-fout-CUIPER.log"
    echo "CUIPER LISTENER FOUT [$CONTEXT]: $BERICHT" >&2
}

# ─── Jaeger span sturen via gedeeld CuiperJaegerSpan.sh ─────────────────────
jaeger_span() {
    local TRACE_ID="$1" SPAN_ID="$2" NAAM="$3"
    local START_NS="$4" EIND_NS="$5"
    local STATUS_CODE="$6" STAP_NR="$7" EXIT_CODE="$8"
    local START_S="${START_NS%000000000}"
    local EIND_S="${EIND_NS%000000000}"
    bash "$_LISTENER_DIR/CuiperJaegerSpan.sh" \
        --trace "$TRACE_ID" --span "$SPAN_ID" --naam "$NAAM" \
        --start "$START_S" --eind "$EIND_S" \
        --status "$STATUS_CODE" --stap "$STAP_NR" --exit "$EXIT_CODE"
}

# ─── Hex genereren voor trace/span IDs ───────────────────────────────────────
rand_hex() {
    local N="$1"
    local HEX_ERR=""
    local RESULT=""
    if ! RESULT=$(cat /dev/urandom | tr -dc '0-9a-f' | head -c "$N" 2>&1); then
        HEX_ERR="$RESULT"
        # Fallback: gebruik RANDOM
        RESULT=""
        for _ in $(seq 1 "$N"); do
            RESULT="${RESULT}$(printf '%x' $((RANDOM % 16)))"
        done
        log_fout "RAND_HEX" "urandom niet beschikbaar, fallback gebruikt: $HEX_ERR"
    fi
    echo "$RESULT"
}

# ─── Argument parsing ─────────────────────────────────────────────────────────
EXEC_CMD=""
NAAM="onbekend"
STAP_NR="0"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --exec) EXEC_CMD="$2"; shift 2 ;;
        --naam) NAAM="$2";     shift 2 ;;
        --stap) STAP_NR="$2";  shift 2 ;;
        *)
            echo "Gebruik: CuiperListener.sh --exec <commando> --naam <naam> --stap <nr>" >&2
            exit 1
            ;;
    esac
done

if [ -z "$EXEC_CMD" ]; then
    echo "FOUT: --exec is verplicht" >&2
    exit 1
fi

# ─── Uitvoering ──────────────────────────────────────────────────────────────
EXEC_ULID=$(ulid)
TRACE_ID=$(rand_hex 32)
SPAN_ID=$(rand_hex 16)
START_S=$(date +%s)
START_NS="${START_S}000000000"
LOGBESTAND="$TRAIL_DIR/${START_S}-listener-${EXEC_ULID}.log"

# Cuip: 01KNLISTENER | $START_S | L:execute | "commando uitvoeren via listener"
printf "ULID:      %s\nTimestamp: %s\nNaam:      %s\nStapNr:    %s\nTrace:     %s\nCommando:  %s\n\n" \
    "$EXEC_ULID" "$START_S" "$NAAM" "$STAP_NR" "$TRACE_ID" "$EXEC_CMD" > "$LOGBESTAND"

echo "=== STDOUT/STDERR ===" >> "$LOGBESTAND"

# Voer uit — stdout en stderr beide naar log en door naar terminal
EXIT_CODE=0
eval "$EXEC_CMD" >> "$LOGBESTAND" 2>&1 || EXIT_CODE=$?

EIND_S=$(date +%s)
EIND_NS="${EIND_S}000000000"

printf "\n=== EINDE ===\nExitCode: %s\nDuur:     %ss\n" \
    "$EXIT_CODE" "$((EIND_S - START_S))" >> "$LOGBESTAND"

# ─── Jaeger span sturen ───────────────────────────────────────────────────────
# Status: 1=OK als exit 0, 2=ERROR anders
STATUS_CODE=1
[ "$EXIT_CODE" -ne 0 ] && STATUS_CODE=2

jaeger_span "$TRACE_ID" "$SPAN_ID" "$NAAM" "$START_NS" "$EIND_NS" \
    "$STATUS_CODE" "$STAP_NR" "$EXIT_CODE"

# ─── Markov resultaat loggen ──────────────────────────────────────────────────
if [ "$EXIT_CODE" -eq 0 ]; then
    printf "Markov:    C == B (succes)\nTraceID:   %s\n" "$TRACE_ID" >> "$LOGBESTAND"
    echo "LISTENER OK [$NAAM] trace=$TRACE_ID duur=$((EIND_S - START_S))s"
else
    printf "Markov:    C != B (exit %s) — rollback vereist\nTraceID:   %s\n" \
        "$EXIT_CODE" "$TRACE_ID" >> "$LOGBESTAND"
    echo "LISTENER FOUT [$NAAM] exit=$EXIT_CODE trace=$TRACE_ID" >&2
fi

exit "$EXIT_CODE"
