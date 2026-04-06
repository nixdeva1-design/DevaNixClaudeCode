#!/usr/bin/env bash
# relay.sh — stuurt diagnose en log data terug naar hoofdnode
# Vereist: consent.sh + connect.sh eerst uitvoeren
# Geen /dev/null — alles is informatie

set -e

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
