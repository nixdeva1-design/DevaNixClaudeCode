#!/usr/bin/env bash
# CuiperModuleLib.sh — gedeelde bibliotheek voor alle CuiperProtocol + CuiperGuest scripts
# Erft via: Cuiper → CuiperCore → CuiperDonut → CuiperClaudeCodeTakenlijst
#
# Biedt:
#   verbose mode:  /v  /vaan  --verbose   aan
#                  /vuit      --no-verbose uit
#   help mode:     /h  /haan  --help       aan
#                  /huit      --no-help     uit
#   CuiperIn/CuiperOut — agnostisch I/O poort definitie
#   cuiper_verbose()           — log naar stderr als CUIPER_VERBOSE=1
#   cuiper_help()              — toon module-kaart (naam/versie/IO/werking/erfenis)
#   cuiper_init_flags "$@"     — parse flags, toon help bij /h, toon banner bij /v
#   cuiper_register_module()   — registreer in PostgreSQL cuiper.entiteiten (non-blocking)
#
# Gebruik in aanroepend script:
#   source "$REPO_ROOT/scripts/protocol/CuiperModuleLib.sh"
#   CUIPER_MODULE_NAAM="CuiperPromptCounter"
#   CUIPER_MODULE_VERSIE="0.2.0"
#   CUIPER_IN="hook"
#   CUIPER_OUT="trail,git,push"
#   CUIPER_MODULE_OMSCHRIJVING="Korte omschrijving"
#   CUIPER_MODULE_WERKING="Gedetailleerde werking"
#   cuiper_init_flags "$@"
#
# /dev/null verbod: alle fouten gaan naar stderr of trail, nooit stil

# ─── Module metadata defaults ────────────────────────────────────────────────
# Overschrijven in aanroepend script vóór cuiper_init_flags
CUIPER_VERBOSE=0
CUIPER_HELP_MODE=0
CUIPER_MODULE_NAAM="${CUIPER_MODULE_NAAM:-onbekend}"
CUIPER_MODULE_VERSIE="${CUIPER_MODULE_VERSIE:-0.1.0}"
CUIPER_IN="${CUIPER_IN:-none}"
CUIPER_OUT="${CUIPER_OUT:-none}"
CUIPER_MODULE_OMSCHRIJVING="${CUIPER_MODULE_OMSCHRIJVING:-geen omschrijving}"
CUIPER_MODULE_WERKING="${CUIPER_MODULE_WERKING:-niet gespecificeerd}"
CUIPER_MODULE_STATUS="${CUIPER_MODULE_STATUS:-ACTIEF}"
CUIPER_MODULE_ERFT_VAN="${CUIPER_MODULE_ERFT_VAN:-CuiperDonut}"

# ─── CuiperIO type constanten ────────────────────────────────────────────────
# Gebruik deze constanten in CUIPER_IN en CUIPER_OUT (komma-gescheiden)
CUIPER_IO_STDIN="stdin"       # standaard input stream
CUIPER_IO_ARGS="args"         # command line argumenten
CUIPER_IO_FILE="file"         # bestandspad
CUIPER_IO_POSTGRES="postgres" # PostgreSQL query/insert
CUIPER_IO_ZENOH="zenoh"       # Zenoh bus event
CUIPER_IO_TRAIL="trail"       # trail log file
CUIPER_IO_GIT="git"           # git output/operatie
CUIPER_IO_HOOK="hook"         # aangeroepen als shell hook (geen directe input)
CUIPER_IO_STDOUT="stdout"     # standaard output stream
CUIPER_IO_STDERR="stderr"     # fout output stream
CUIPER_IO_NONE="none"         # geen input of output

# ─── cuiper_init_flags ───────────────────────────────────────────────────────
# Parse /v /vaan /vuit /h /haan /huit en alle lang-varianten
# Na parse: toon help (en exit) of toon verbose banner
cuiper_init_flags() {
    CUIPER_VERBOSE=0
    CUIPER_HELP_MODE=0
    for _clf_arg in "$@"; do
        case "$_clf_arg" in
            /v|/vaan|--verbose|-v)    CUIPER_VERBOSE=1 ;;
            /vuit|--no-verbose)       CUIPER_VERBOSE=0 ;;
            /h|/haan|--help|-h)       CUIPER_HELP_MODE=1 ;;
            /huit|--no-help)          CUIPER_HELP_MODE=0 ;;
        esac
    done
    unset _clf_arg

    if [ "${CUIPER_HELP_MODE}" -eq 1 ]; then
        cuiper_help
        exit 0
    fi

    if [ "${CUIPER_VERBOSE}" -eq 1 ]; then
        cuiper_verbose "module geladen:  ${CUIPER_MODULE_NAAM} v${CUIPER_MODULE_VERSIE}"
        cuiper_verbose "CuiperIn:        ${CUIPER_IN}"
        cuiper_verbose "CuiperOut:       ${CUIPER_OUT}"
        cuiper_verbose "Status:          ${CUIPER_MODULE_STATUS}"
        cuiper_verbose "Erft van:        ${CUIPER_MODULE_ERFT_VAN}"
    fi
}

# ─── cuiper_verbose ──────────────────────────────────────────────────────────
# Log bericht naar stderr alleen als CUIPER_VERBOSE=1
cuiper_verbose() {
    [ "${CUIPER_VERBOSE:-0}" -eq 1 ] && printf "[%s] VERBOSE: %s\n" "${CUIPER_MODULE_NAAM}" "$*" >&2
}

# ─── cuiper_help ─────────────────────────────────────────────────────────────
# Toon module-kaart: naam, versie, omschrijving, werking, IO, flags, erfenis
cuiper_help() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  Module:       %s\n"  "${CUIPER_MODULE_NAAM}"
    printf "  Versie:       %s\n"  "${CUIPER_MODULE_VERSIE}"
    printf "  Status:       %s\n"  "${CUIPER_MODULE_STATUS}"
    echo   ""
    printf "  Omschrijving: %s\n"  "${CUIPER_MODULE_OMSCHRIJVING}"
    printf "  Werking:      %s\n"  "${CUIPER_MODULE_WERKING}"
    echo   ""
    printf "  CuiperIn:     %s\n"  "${CUIPER_IN}"
    printf "  CuiperOut:    %s\n"  "${CUIPER_OUT}"
    echo   ""
    echo   "  Flags:"
    echo   "    /v   /vaan  --verbose      Verbose mode aan (meer output naar stderr)"
    echo   "    /vuit        --no-verbose  Verbose mode uit"
    echo   "    /h   /haan  --help         Deze module-kaart tonen en exit"
    echo   "    /huit        --no-help     Help mode uit"
    echo   ""
    printf "  Erfenis: Cuiper → CuiperCore → CuiperDonut → %s\n" "${CUIPER_MODULE_ERFT_VAN:+${CUIPER_MODULE_ERFT_VAN} → }${CUIPER_MODULE_NAAM}"
    echo   "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ─── cuiper_register_module ───────────────────────────────────────────────────
# Registreer module in PostgreSQL cuiper.entiteiten
# Non-blocking: als psql niet beschikbaar of DB down → gesedimenteerd in trail, script gaat door
# Aanroepen na cuiper_init_flags, met eigen ULID als argument
# Gebruik: cuiper_register_module "<ulid>"
cuiper_register_module() {
    local _ulid="${1:-}"
    local _unix_ts
    _unix_ts=$(date +%s)

    if [ -z "$_ulid" ]; then
        cuiper_verbose "register_module: geen ULID meegegeven — overgeslagen"
        return 0
    fi

    if ! command -v psql >/dev/null 2>&1; then
        cuiper_verbose "register_module: psql niet beschikbaar — PostgreSQL registratie overgeslagen"
        return 0
    fi

    local _db_url="${CUIPER_PG_URL:-${CUIPER_DB_URL:-postgresql://localhost/cuiper}}"

    local _naam_esc
    _naam_esc=$(printf '%s' "${CUIPER_MODULE_NAAM}" | sed "s/'/''/g")
    local _omschrijving_esc
    _omschrijving_esc=$(printf '%s' "${CUIPER_MODULE_OMSCHRIJVING}" | sed "s/'/''/g")
    local _werking_esc
    _werking_esc=$(printf '%s' "${CUIPER_MODULE_WERKING}" | sed "s/'/''/g")
    local _in_esc
    _in_esc=$(printf '%s' "${CUIPER_IN}" | sed "s/'/''/g")
    local _out_esc
    _out_esc=$(printf '%s' "${CUIPER_OUT}" | sed "s/'/''/g")

    local _pg_out
    if ! _pg_out=$(psql "$_db_url" -c "
        INSERT INTO cuiper.entiteiten (
            ulid, unix_ts, naam, omschrijving, werking,
            status, versie_nr, cuiper_in, cuiper_out, erft_van
        ) VALUES (
            '${_ulid}', ${_unix_ts}, '${_naam_esc}',
            '${_omschrijving_esc}', '${_werking_esc}',
            '${CUIPER_MODULE_STATUS}', '${CUIPER_MODULE_VERSIE}',
            '${_in_esc}', '${_out_esc}', '${CUIPER_MODULE_ERFT_VAN}'
        )
        ON CONFLICT (naam) DO UPDATE SET
            unix_ts      = EXCLUDED.unix_ts,
            omschrijving = EXCLUDED.omschrijving,
            werking      = EXCLUDED.werking,
            status       = EXCLUDED.status,
            versie_nr    = EXCLUDED.versie_nr,
            cuiper_in    = EXCLUDED.cuiper_in,
            cuiper_out   = EXCLUDED.cuiper_out,
            erft_van     = EXCLUDED.erft_van,
            aangepast_ts = EXCLUDED.unix_ts;
    " 2>&1); then
        cuiper_verbose "register_module: postgres fout — ${_pg_out}"
        # /dev/null verbod: log fout naar trail als trail dir bekend is
        if [ -n "${CUIPER_TRAIL_DIR:-}" ] && [ -d "${CUIPER_TRAIL_DIR}" ]; then
            printf "%s CUIPER_REG_FOUT [%s]: %s\n" \
                "$(date +%s)" "${CUIPER_MODULE_NAAM}" "${_pg_out}" \
                >> "${CUIPER_TRAIL_DIR}/$(date +%s)-reg-fout-CUIPER.log"
        fi
        return 0  # non-blocking: nooit het hoofdscript blokkeren
    fi

    cuiper_verbose "register_module: geregistreerd in cuiper.entiteiten (${CUIPER_MODULE_NAAM} v${CUIPER_MODULE_VERSIE})"
}

# ─── cuiper_amendeer_relatie_kolom ───────────────────────────────────────────
# Voeg relatie-kolom toe aan cuiper.entiteiten als deze nog niet bestaat
# Regel: bestaat een kolom niet → aanmaken. Nooit weggooien.
# Gebruik: cuiper_amendeer_relatie_kolom "verbonden_met" "TEXT"
cuiper_amendeer_relatie_kolom() {
    local _kolom="${1:-}"
    local _type="${2:-TEXT}"

    if [ -z "$_kolom" ]; then
        cuiper_verbose "amendeer_relatie_kolom: geen kolomnaam meegegeven"
        return 1
    fi

    if ! command -v psql >/dev/null 2>&1; then
        cuiper_verbose "amendeer_relatie_kolom: psql niet beschikbaar"
        return 0
    fi

    local _db_url="${CUIPER_PG_URL:-${CUIPER_DB_URL:-postgresql://localhost/cuiper}}"
    local _pg_out

    if ! _pg_out=$(psql "$_db_url" -c "
        ALTER TABLE cuiper.entiteiten
        ADD COLUMN IF NOT EXISTS ${_kolom} ${_type};
    " 2>&1); then
        cuiper_verbose "amendeer_relatie_kolom: fout bij ADD COLUMN ${_kolom}: ${_pg_out}"
        return 0  # non-blocking
    fi

    cuiper_verbose "amendeer_relatie_kolom: kolom '${_kolom}' geamendeerd (${_type})"
}
