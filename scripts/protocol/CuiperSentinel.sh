#!/usr/bin/env bash
# CuiperSentinel — bewaakt de staat van de repo continu
# Detecteert: sessie-onderbreking, stroomuitval, geen connectie
# Bij gevaar: commit en push automatisch
# Draait als achtergrond proces tijdens elke sessie
# Geen /dev/null — alles is informatie

set -e

# ─── CuiperModuleLib ─────────────────────────────────────────────────────────
_CUIPER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/protocol/CuiperModuleLib.sh
source "${_CUIPER_LIB_DIR}/CuiperModuleLib.sh" 2>/dev/null || true
CUIPER_MODULE_NAAM="CuiperSentinel"
CUIPER_MODULE_VERSIE="0.2.0"
CUIPER_IN="hook"
CUIPER_OUT="trail,git,push"
CUIPER_MODULE_OMSCHRIJVING="Bewaakt de staat van de repo continu — redt bij onderbreking"
CUIPER_MODULE_WERKING="Achtergrond proces. Detecteert sessie-onderbreking. Auto-commit+push."
cuiper_init_flags "$@"
# ─────────────────────────────────────────────────────────────────────────────


# ─── Centrale config — geen hardcoded paden ───────────────────────────────
_SENTINEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_SENTINEL_DIR/../../CuiperConfig.env"
unset _SENTINEL_DIR

REPO="$CUIPER_REPO"
LOGDIR="$CUIPER_TRAIL_DIR"
INTERVAL=30  # seconden tussen checks

mkdir -p "$LOGDIR"

ulid() {
  local ENC="0123456789ABCDEFGHJKMNPQRSTVWXYZ"
  local ts n t r
  ts=$(date +%s%3N); n=$ts; t=""
  for i in $(seq 1 10); do t="${ENC:$((n%32)):1}${t}"; n=$((n/32)); done
  r=""
  for i in $(seq 1 16); do r="${r}${ENC:$((RANDOM%32)):1}"; done
  echo "${t}${r}"
}

log() {
  local MSG="$1"
  local TS=$(date +%s)
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SENTINEL: ${MSG}" | tee -a "${LOGDIR}/sentinel.log"
}

sentinel_commit() {
  local REDEN="$1"
  local ULID=$(ulid)
  local TS=$(date +%s)

  cd "$REPO"

  if git diff --quiet && git diff --cached --quiet; then
    log "Geen wijzigingen om op te slaan."
    return 0
  fi

  log "Wijzigingen gevonden. Reden: ${REDEN}"

  git add -A

  git commit -m "CuiperSentinel: automatisch opgeslagen
Reden: ${REDEN}
ULID: ${ULID}
Tijdstip: ${TS}

https://claude.ai/code/session_01LwAQ3fvpdvRMMTi8o92pKu" \
    >> "${LOGDIR}/sentinel.log" 2>&1

  # Push met retry
  local POGING=0
  while [ $POGING -lt 4 ]; do
    if git push >> "${LOGDIR}/sentinel.log" 2>&1; then
      log "Push geslaagd. ULID: ${ULID}"
      return 0
    fi
    POGING=$((POGING + 1))
    WACHT=$((2 ** POGING))
    log "Push mislukt. Poging ${POGING}/4. Wacht ${WACHT}s."
    sleep $WACHT
  done

  log "KRITIEK: Push mislukt na 4 pogingen. Data lokaal bewaard."
}

# ─── Signaal handlers ─────────────────────────────────────────────────────
# Vang stroomuitval / sessie-onderbreking op

trap 'log "SIGTERM ontvangen"; sentinel_commit "SIGTERM sessie-einde"; exit 0' TERM
trap 'log "SIGINT ontvangen"; sentinel_commit "SIGINT onderbreking"; exit 0' INT
trap 'log "SIGHUP ontvangen"; sentinel_commit "SIGHUP verbinding verbroken"; exit 0' HUP

log "CuiperSentinel gestart. Interval: ${INTERVAL}s"

# ─── Bewakingslus ─────────────────────────────────────────────────────────
while true; do
  cd "$REPO"

  # Check ongecommittede wijzigingen
  if ! git diff --quiet || ! git diff --cached --quiet; then
    # Hoe lang al ongecommitteed?
    LAATSTE=$(git log -1 --format="%ct" 2>/dev/null || echo 0)
    NU=$(date +%s)
    DELTA=$((NU - LAATSTE))

    # Na 5 minuten automatisch opslaan
    if [ $DELTA -gt 300 ]; then
      sentinel_commit "automatisch na ${DELTA}s ongecommitteed"
    fi
  fi

  # Check internet verbinding
  if ! ping -c 1 -W 2 8.8.8.8 >> "${LOGDIR}/sentinel.log" 2>&1; then
    log "WAARSCHUWING: Geen internetverbinding gedetecteerd"
  fi

  sleep $INTERVAL
done
