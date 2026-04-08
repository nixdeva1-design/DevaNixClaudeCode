#!/usr/bin/env bash
# relay.sh — stuurt diagnose en log data terug naar hoofdnode
# Vereist: consent.sh + connect.sh eerst uitvoeren
# Geen /dev/null — alles is informatie

set -e

# ─── CuiperModuleLib ─────────────────────────────────────────────────────────
_CUIPER_GUEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/protocol/CuiperModuleLib.sh
source "${_CUIPER_GUEST_DIR}/../protocol/CuiperModuleLib.sh" 2>/dev/null || true
CUIPER_MODULE_NAAM="CuiperRelay"
CUIPER_MODULE_VERSIE="0.2.0"
CUIPER_IN="stdin"
CUIPER_OUT="stdout"
CUIPER_MODULE_OMSCHRIJVING="Relay: stuurt berichten door tussen gastcomputer en hoofdnode"
CUIPER_MODULE_WERKING="Transparante doorstuurlaag. Geen state. Alles gelogd."
cuiper_init_flags "$@"
# ─────────────────────────────────────────────────────────────────────────────


SCRIPT_DIR="$(dirname "$0")"
CONSENT_FILE="${SCRIPT_DIR}/.consent"

if [ ! -f "$CONSENT_FILE" ]; then
  echo "FOUT: Geen toestemming. Voer eerst consent.sh uit."
  exit 1
fi

source "$CONSENT_FILE"

TS=$(date +%s)
LOGDIR="${SCRIPT_DIR}/../../logs/trail"
LOGFILE="${LOGDIR}/${TS}-relay-${CONSENT_HASH}.log"

log() {
  echo "$1" | tee -a "$LOGFILE"
}

log "Relay gestart naar hoofdnode: ${HOOFDNODE_IP}"
log "Namespace: ${NAMESPACE}"

# Alle logs van deze sessie verzamelen
SESSIE_LOGS=$(find "$LOGDIR" -name "*${CONSENT_HASH}*" -type f)

for LOG in $SESSIE_LOGS; do
  log "Versturen: ${LOG}"

  # Via SCP naar hoofdnode
  scp "$LOG" "reparateur@${HOOFDNODE_IP}:/projects/" 2>&1 | tee -a "$LOGFILE" \
    && log "Verzonden: $(basename "$LOG")" \
    || log "FOUT bij verzenden: $(basename "$LOG") — bewaard lokaal"
done

log "Relay klaar."
