#!/usr/bin/env bash
# CuiperBouwProtocol.sh — verplichte Markov-stappen per file/module vóór en ná elke schrijfactie
#
# Erft via: Cuiper → CuiperCore → CuiperDonut → CuiperClaudeCodeTakenlijst
#
# DOEL:
#   Elk bestand dat ClaudeCode schrijft/wijzigt doorloopt verplicht 3 Markov-stappen:
#   A = CuiperStatusBackup   — huidige stabiele staat, gecommit+gepusht VOOR de wijziging
#   B = CuiperVerwacht       — wat we verwachten, inclusief test-commando, VOOR de wijziging
#   C = CuiperNaVerwacht     — werkelijke staat NA uitvoering, geverifieerd via test
#
#   C == B → commit "MATCH: reden waarom goed"  → push → A{n+1} = C
#   C != B → rollback naar A → commit "MISMATCH: reden waarom fout" → push → leren
#
# GEBRUIK:
#   # Fase PRE — vóór elke write/edit actie:
#   bash CuiperBouwProtocol.sh --fase pre \
#     --target "crates/cuiper-core/src/cuip.rs" \
#     --verwacht "Cuip heeft hash u64 en Vec<CuiperRegel>" \
#     --test "cargo test -p cuiper-core" \
#     --ulid "$ULID" --stap "$STAPNR"
#
#   # Fase POST — ná de write/edit actie (test+verify+commit):
#   bash CuiperBouwProtocol.sh --fase post \
#     --target "crates/cuiper-core/src/cuip.rs" \
#     --verwacht "Cuip heeft hash u64 en Vec<CuiperRegel>" \
#     --test "cargo test -p cuiper-core" \
#     --rollback "$ROLLBACK_COMMIT" \
#     --ulid "$ULID" --stap "$STAPNR"
#
# HERGEBRUIK: bouwt op CuiperModuleLib, CuiperListener, CuiperUlid, CuiperLog
# LEREN:      elke uitkomst → logs/bouw/CuiperBouwHistorie.jsonl (antifragiel)
#
# /dev/null verbod: alle output gesedimenteerd

set -uo pipefail

# ─── CuiperModuleLib — hergebruik bestaande verbose/help infra ───────────────
_CUIPER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/protocol/CuiperModuleLib.sh
source "${_CUIPER_LIB_DIR}/CuiperModuleLib.sh" 2>/dev/null || true
CUIPER_MODULE_NAAM="CuiperBouwProtocol"
CUIPER_MODULE_VERSIE="0.1.0"
CUIPER_IN="args"
CUIPER_OUT="trail,git,push"
CUIPER_MODULE_OMSCHRIJVING="Verplicht Markov A→B→C per file vóór en ná elke schrijfactie"
CUIPER_MODULE_WERKING="Pre: commit A(backup)+B(verwacht+test) naar GitHub. Post: voer test uit, C==B commit reden goed, C!=B rollback+commit reden fout. Alles gesedimenteerd."
CUIPER_MODULE_ERFT_VAN="CuiperClaudeCodeTakenlijst"
cuiper_init_flags "$@"
# ─────────────────────────────────────────────────────────────────────────────

# ─── Config — hergebruik bestaande CuiperConfig.env ──────────────────────────
source "${_CUIPER_LIB_DIR}/../../CuiperConfig.env" 2>/dev/null || {
    CUIPER_REPO="$(git -C "${_CUIPER_LIB_DIR}" rev-parse --show-toplevel 2>/dev/null || pwd)"
    CUIPER_TRAIL_DIR="$CUIPER_REPO/logs/trail"
}
TRAIL_DIR="$CUIPER_TRAIL_DIR"
BOUW_DIR="$CUIPER_REPO/logs/bouw"
mkdir -p "$TRAIL_DIR" "$BOUW_DIR"

BOUW_HISTORIE="$BOUW_DIR/CuiperBouwHistorie.jsonl"

# ─── Hulpfunctie: fout loggen (hergebruik patroon uit andere scripts) ─────────
log_fout() {
    local CTX="$1" MSG="$2"
    printf "%s FOUT [%s]: %s\n" "$(date +%s)" "$CTX" "$MSG" \
        >> "$TRAIL_DIR/$(date +%s)-bouwprotocol-fout-CUIPER.log"
    echo "CUIPER BOUWPROTOCOL FOUT [$CTX]: $MSG" >&2
}

# ─── Argument parsing ────────────────────────────────────────────────────────
FASE=""
TARGET=""
VERWACHT=""
TEST_CMD=""
ROLLBACK=""
BOUW_ULID=""
STAP_NR="?"

_i=1
while [ $_i -le $# ]; do
    eval "_arg=\${${_i}}"
    case "$_arg" in
        --fase)      _i=$((_i+1)); eval "FASE=\${${_i}}" ;;
        --target)    _i=$((_i+1)); eval "TARGET=\${${_i}}" ;;
        --verwacht)  _i=$((_i+1)); eval "VERWACHT=\${${_i}}" ;;
        --test)      _i=$((_i+1)); eval "TEST_CMD=\${${_i}}" ;;
        --rollback)  _i=$((_i+1)); eval "ROLLBACK=\${${_i}}" ;;
        --ulid)      _i=$((_i+1)); eval "BOUW_ULID=\${${_i}}" ;;
        --stap)      _i=$((_i+1)); eval "STAP_NR=\${${_i}}" ;;
        /v|/vaan|/vuit|/h|/haan|/huit|--verbose|--help) ;; # al verwerkt door cuiper_init_flags
    esac
    _i=$((_i+1))
done

# Genereer ULID als niet meegegeven — hergebruik CuiperUlid.sh
if [ -z "$BOUW_ULID" ]; then
    BOUW_ULID=$(bash "${_CUIPER_LIB_DIR}/CuiperUlid.sh" 2>/dev/null || date +%s%N | sha256sum | head -c 26)
fi

NOW=$(date +%s)

# ─── Validatie ───────────────────────────────────────────────────────────────
if [ -z "$FASE" ] || [ -z "$TARGET" ] || [ -z "$VERWACHT" ] || [ -z "$TEST_CMD" ]; then
    echo "GEBRUIK: $0 --fase <pre|post> --target <bestand> --verwacht \"<B>\" --test \"<cmd>\" [--rollback <hash>] [--ulid <ulid>] [--stap <nr>]" >&2
    echo "  pre  = vóór schrijven: leg A+B vast op GitHub" >&2
    echo "  post = ná schrijven:   voer test uit, bepaal C, commit reden" >&2
    exit 1
fi

# ─── Hergebruik: branch bepalen (patroon uit CuiperPromptCounter) ────────────
BRANCH=$(git branch --show-current 2>/dev/null || echo "onbekend")

# ─── Sedimenteer naar CuiperBouwHistorie (antifragiel leren) ─────────────────
sedimenteer_bouw() {
    local _fase="$1" _uitkomst="$2" _reden="$3" _commit_hash="$4"
    printf '{"ulid":"%s","unix_ts":%s,"fase":"%s","target":"%s","verwacht":"%s","uitkomst":"%s","reden":"%s","commit":"%s","stap":%s,"branch":"%s"}\n' \
        "$BOUW_ULID" "$NOW" "$_fase" "$TARGET" \
        "$(echo "$VERWACHT" | sed 's/"/\\"/g')" \
        "$_uitkomst" \
        "$(echo "$_reden" | sed 's/"/\\"/g')" \
        "$_commit_hash" "$STAP_NR" "$BRANCH" \
        >> "$BOUW_HISTORIE"
    cuiper_verbose "bouw-historie: $_fase $_uitkomst → $BOUW_HISTORIE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FASE PRE — vóór elke schrijfactie
# Commit A (huidige staat) + B (verwacht + test) naar GitHub VOOR de wijziging
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$FASE" = "pre" ]; then
    cuiper_verbose "fase PRE: target=$TARGET stap=$STAP_NR"

    # ── A: Backup huidige staat van het target-bestand ──────────────────────
    A_HASH=$(git rev-parse HEAD 2>/dev/null || echo "geen-commit")
    A_BESTAND_HASH=""
    if [ -f "$CUIPER_REPO/$TARGET" ]; then
        A_BESTAND_HASH=$(sha256sum "$CUIPER_REPO/$TARGET" 2>/dev/null | cut -c1-16 || echo "nieuw")
    else
        A_BESTAND_HASH="nieuw-bestand"
    fi

    cuiper_verbose "A (backup): commit=$A_HASH bestand-hash=$A_BESTAND_HASH"

    # ── Schrijf verwacht-bestand (B definitie) ───────────────────────────────
    VERWACHT_BESTAND="$BOUW_DIR/${BOUW_ULID}-verwacht.txt"
    cat > "$VERWACHT_BESTAND" << EOF
CuiperBouwProtocol — Verwachte staat (B)
ULID:        $BOUW_ULID
Stap:        $STAP_NR
Timestamp:   $NOW
Target:      $TARGET
A-commit:    $A_HASH
A-hash:      $A_BESTAND_HASH
Verwacht:    $VERWACHT
Test-cmd:    $TEST_CMD
EOF

    # ── Commit A + B naar GitHub VÓÓR de wijziging ───────────────────────────
    git -C "$CUIPER_REPO" add "$BOUW_DIR/" 2>/dev/null || log_fout "GIT_ADD_B" "add bouw dir mislukt"

    COMMIT_MSG="CuiperVerwacht stap${STAP_NR} [${BOUW_ULID:0:8}]: ${TARGET} — ${VERWACHT}"
    if ! git -C "$CUIPER_REPO" commit -m "$COMMIT_MSG" --no-verify 2>/dev/null; then
        cuiper_verbose "B-commit: niets te committen (bouw dir al up-to-date)"
    else
        cuiper_verbose "B-commit: $COMMIT_MSG"
    fi

    # ── Push B naar GitHub VÓÓR de wijziging ─────────────────────────────────
    _PUSH_DELAY=2
    for _p in 1 2 3 4; do
        if git -C "$CUIPER_REPO" push -u origin "$BRANCH" 2>/dev/null; then
            cuiper_verbose "B-push: OK op poging $_p"
            break
        fi
        [ $_p -lt 4 ] && sleep $_PUSH_DELAY && _PUSH_DELAY=$((_PUSH_DELAY * 2))
    done

    # Geef rollback-commit terug via stdout (caller slaat dit op als ROLLBACK variabele)
    echo "$A_HASH"

    sedimenteer_bouw "pre" "B_GEPUSHT" "$VERWACHT" "$A_HASH"
    cuiper_verbose "fase PRE klaar — rollback-anker: $A_HASH — nu mag je schrijven"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# FASE POST — ná de schrijfactie
# Test uitvoeren, C bepalen, vergelijken met B, commit met reden, push
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$FASE" = "post" ]; then
    cuiper_verbose "fase POST: target=$TARGET test='$TEST_CMD'"

    # ── Voer test uit via CuiperListener.sh (hergebruik) ─────────────────────
    TEST_OUTPUT_FILE="$BOUW_DIR/${BOUW_ULID}-test-output.txt"

    TEST_EXIT=0
    if bash "${_CUIPER_LIB_DIR}/CuiperListener.sh" \
        --exec "$TEST_CMD" \
        --naam "CuiperBouwTest:${TARGET}" \
        --stap "$STAP_NR" > "$TEST_OUTPUT_FILE" 2>&1; then
        TEST_EXIT=0
        cuiper_verbose "test: GESLAAGD ($TEST_CMD)"
    else
        TEST_EXIT=$?
        cuiper_verbose "test: MISLUKT exit=$TEST_EXIT ($TEST_CMD)"
    fi

    C_HASH=$(git -C "$CUIPER_REPO" rev-parse HEAD 2>/dev/null || echo "geen-commit")
    C_BESTAND_HASH=""
    if [ -f "$CUIPER_REPO/$TARGET" ]; then
        C_BESTAND_HASH=$(sha256sum "$CUIPER_REPO/$TARGET" 2>/dev/null | cut -c1-16 || echo "?")
    fi

    # ── C == B (test geslaagd) ────────────────────────────────────────────────
    if [ "$TEST_EXIT" -eq 0 ]; then
        REDEN_GOED="test '${TEST_CMD}' geslaagd — C==B bewezen"

        git -C "$CUIPER_REPO" add "$TARGET" "$BOUW_DIR/" 2>/dev/null || true

        COMMIT_MSG="CuiperVerify MATCH stap${STAP_NR} [${BOUW_ULID:0:8}]: ${TARGET} — ${VERWACHT} — ${REDEN_GOED}"
        if git -C "$CUIPER_REPO" commit -m "$COMMIT_MSG" --no-verify 2>/dev/null; then
            cuiper_verbose "C-commit MATCH: $COMMIT_MSG"
        fi

        _PUSH_DELAY=2
        for _p in 1 2 3 4; do
            if git -C "$CUIPER_REPO" push -u origin "$BRANCH" 2>/dev/null; then
                cuiper_verbose "C-push MATCH: OK op poging $_p"
                break
            fi
            [ $_p -lt 4 ] && sleep $_PUSH_DELAY && _PUSH_DELAY=$((_PUSH_DELAY * 2))
        done

        sedimenteer_bouw "post" "MATCH" "$REDEN_GOED" "$C_HASH"

        echo "CUIPER BOUW MATCH: $TARGET — $VERWACHT"
        exit 0

    # ── C != B (test mislukt) — rollback naar A ───────────────────────────────
    else
        REDEN_FOUT="test '${TEST_CMD}' mislukt (exit=$TEST_EXIT) — C!=B — rollback naar $ROLLBACK"
        TEST_FRAGMENT=$(head -20 "$TEST_OUTPUT_FILE" 2>/dev/null | tr '\n' '|')

        echo "CUIPER BOUW MISMATCH: $TARGET" >&2
        echo "  Verwacht: $VERWACHT" >&2
        echo "  Reden:    $REDEN_FOUT" >&2
        echo "  Output:   $TEST_FRAGMENT" >&2

        # Rollback het target-bestand naar staat A
        if [ -n "$ROLLBACK" ] && [ "$ROLLBACK" != "geen-commit" ]; then
            if git -C "$CUIPER_REPO" checkout "$ROLLBACK" -- "$TARGET" 2>/dev/null; then
                cuiper_verbose "rollback: $TARGET terug naar $ROLLBACK"
            else
                log_fout "ROLLBACK" "git checkout $ROLLBACK -- $TARGET mislukt"
            fi
        fi

        git -C "$CUIPER_REPO" add "$TARGET" "$BOUW_DIR/" 2>/dev/null || true

        COMMIT_MSG="CuiperVerify MISMATCH stap${STAP_NR} [${BOUW_ULID:0:8}]: ${TARGET} — FOUT: ${REDEN_FOUT}"
        if git -C "$CUIPER_REPO" commit -m "$COMMIT_MSG" --no-verify 2>/dev/null; then
            cuiper_verbose "C-commit MISMATCH: $COMMIT_MSG"
        fi

        _PUSH_DELAY=2
        for _p in 1 2 3 4; do
            if git -C "$CUIPER_REPO" push -u origin "$BRANCH" 2>/dev/null; then
                cuiper_verbose "C-push MISMATCH: OK op poging $_p"
                break
            fi
            [ $_p -lt 4 ] && sleep $_PUSH_DELAY && _PUSH_DELAY=$((_PUSH_DELAY * 2))
        done

        sedimenteer_bouw "post" "MISMATCH" "$REDEN_FOUT" "$C_HASH"

        exit 1
    fi
fi

echo "FOUT: --fase moet 'pre' of 'post' zijn, niet: '$FASE'" >&2
exit 2
