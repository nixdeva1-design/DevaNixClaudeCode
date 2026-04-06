#!/usr/bin/env bash
# listener.sh — ontvangt en voert commando's uit van hoofdnode
# Vereist: consent.sh + connect.sh eerst uitvoeren
# Alle output gelogd — geen /dev/null
# Klant ziet alles wat er uitgevoerd wordt

set -e

SCRIPT_DIR="$(dirname "$0")"
CONSENT_FILE="${SCRIPT_DIR}/.consent"

# Consent check
if [ ! -f "$CONSENT_FILE" ]; then
  echo "FOUT: Geen toestemming. Voer eerst consent.sh uit."
  exit 1
fi

source "$CONSENT_FILE"

TS=$(date +%s)
LOGDIR="${SCRIPT_DIR}/../../logs/trail"
mkdir -p "$LOGDIR"
LOGFILE="${LOGDIR}/${TS}-listener-${CONSENT_HASH}.log"
CMDLOG="${LOGDIR}/${TS}-commands-${CONSENT_HASH}.log"

log() {
  echo "$1" | tee -a "$LOGFILE"
}

log "═══════════════════════════════════════════════════"
log "CuiperHive Listener actief"
log "Klant:     ${CONSENT_KLANT}"
log "Hash:      ${CONSENT_HASH}"
log "Namespace: ${NAMESPACE}"
log "Tijdstip:  $(date '+%Y-%m-%d %H:%M:%S')"
log "═══════════════════════════════════════════════════"
log ""
log "Wachtend op commando's van hoofdnode..."
log "Alle uitgevoerde commando's worden getoond en gelogd."
log ""

# Commando queue bestand — hoofdnode schrijft hierin
QUEUE_FILE="${SCRIPT_DIR}/.cmdqueue"
> "$QUEUE_FILE"

# Listener loop
while true; do
  if [ -s "$QUEUE_FILE" ]; then
    CMD=$(head -1 "$QUEUE_FILE")
    tail -n +2 "$QUEUE_FILE" > "${QUEUE_FILE}.tmp"
    mv "${QUEUE_FILE}.tmp" "$QUEUE_FILE"

    if [ "$CMD" = "STOP" ]; then
      log "STOP ontvangen. Listener stopt."
      break
    fi

    # Klant ziet wat er uitgevoerd wordt
    echo "══ Uitvoeren: ${CMD}"
    echo "$(date '+%H:%M:%S') CMD: ${CMD}" >> "$CMDLOG"

    # Uitvoeren en alles loggen
    eval "$CMD" 2>&1 | tee -a "$LOGFILE" "$CMDLOG"

    echo "$(date '+%H:%M:%S') KLAAR: ${CMD}" >> "$CMDLOG"
    echo "── Klaar ──"
  fi

  sleep 1
done

log ""
log "Listener gestopt. Log: ${LOGFILE}"
log "Commando log: ${CMDLOG}"
