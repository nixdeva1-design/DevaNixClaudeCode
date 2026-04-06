#!/usr/bin/env bash
# connect.sh — verbindt gastcomputer met hoofdnode via Zenoh
# Vereist: consent.sh eerst uitvoeren
# Hoofdnode adres meegeven: connect.sh <hoofdnode-ip>
# Geen /dev/null — alles is informatie

set -e

SCRIPT_DIR="$(dirname "$0")"
CONSENT_FILE="${SCRIPT_DIR}/.consent"
HOOFDNODE_IP="${1}"

# Consent check
if [ ! -f "$CONSENT_FILE" ]; then
  echo "FOUT: Geen toestemming. Voer eerst consent.sh uit."
  exit 1
fi

source "$CONSENT_FILE"

if [ -z "$HOOFDNODE_IP" ]; then
  echo "Gebruik: connect.sh <hoofdnode-ip>"
  echo "Voorbeeld: connect.sh 192.168.1.100"
  exit 1
fi

TS=$(date +%s)
LOGDIR="${SCRIPT_DIR}/../../logs/trail"
mkdir -p "$LOGDIR"
LOGFILE="${LOGDIR}/${TS}-connect-${CONSENT_HASH}.log"

log() {
  echo "$1" | tee -a "$LOGFILE"
}

log "Verbinding opzetten naar hoofdnode: ${HOOFDNODE_IP}"
log "Klant hash: ${CONSENT_HASH}"
log "Tijdstip: $(date '+%Y-%m-%d %H:%M:%S')"

# Namespace voor deze gast — geïsoleerd per klant
NAMESPACE="klant/${CONSENT_HASH}"
log "Zenoh namespace: ${NAMESPACE}"

# Controleer of zenohd beschikbaar is
if ! command -v zenohd &> /dev/null; then
  log "Zenoh niet gevonden op gastcomputer."
  log "Verbinding via SSH fallback..."

  # SSH tunnel als fallback
  ssh -N -R 7447:localhost:7447 "reparateur@${HOOFDNODE_IP}" &
  SSH_PID=$!
  echo "SSH_PID=${SSH_PID}" >> "$CONSENT_FILE"
  log "SSH tunnel actief. PID: ${SSH_PID}"
else
  # Zenoh peer verbinding
  zenohd --connect "tcp/${HOOFDNODE_IP}:7447" \
         --id "gast-${CONSENT_HASH}" \
    >> "$LOGFILE" 2>&1 &
  ZENOH_PID=$!
  echo "ZENOH_PID=${ZENOH_PID}" >> "$CONSENT_FILE"
  log "Zenoh verbinding actief. PID: ${ZENOH_PID}"
fi

echo "HOOFDNODE_IP=${HOOFDNODE_IP}" >> "$CONSENT_FILE"
echo "NAMESPACE=${NAMESPACE}" >> "$CONSENT_FILE"

log "Verbinding klaar. Hoofdnode kan nu werken op gast."
