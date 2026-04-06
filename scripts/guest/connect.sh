#!/usr/bin/env bash
# connect.sh — verbindt gastcomputer met hoofdnode
# Transport automatisch bepaald op basis van adres en modus
# Gebruik:
#   connect.sh <ip>              lokaal netwerk of WiFi
#   connect.sh <domein>          internet
#   connect.sh <ip> vpn          via VPN tunnel
# Geen /dev/null — alles is informatie

set -e

SCRIPT_DIR="$(dirname "$0")"
CONSENT_FILE="${SCRIPT_DIR}/.consent"
HOOFDNODE="${1}"
MODUS="${2:-auto}"

if [ ! -f "$CONSENT_FILE" ]; then
  echo "FOUT: Geen toestemming. Voer eerst consent.sh uit."
  exit 1
fi

source "$CONSENT_FILE"

if [ -z "$HOOFDNODE" ]; then
  echo "Gebruik: connect.sh <ip-of-domein> [vpn]"
  exit 1
fi

TS=$(date +%s)
LOGDIR="${SCRIPT_DIR}/../../logs/trail"
mkdir -p "$LOGDIR"
LOGFILE="${LOGDIR}/${TS}-connect-${CONSENT_HASH}.log"

log() {
  echo "$1" | tee -a "$LOGFILE"
}

# ─── Transport bepalen ────────────────────────────────────────
# Lokaal: 192.168.x.x / 10.x.x.x / 172.16-31.x.x
# Internet: alles anders
is_lokaal() {
  echo "$1" | grep -qE '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)'
}

log "═══════════════════════════════════════════════════"
log "CuiperHive Verbinding"
log "Hoofdnode:  ${HOOFDNODE}"
log "Modus:      ${MODUS}"
log "Tijdstip:   $(date '+%Y-%m-%d %H:%M:%S')"
log "Hash:       ${CONSENT_HASH}"

if [ "$MODUS" = "vpn" ]; then
  TRANSPORT="vpn"
elif is_lokaal "$HOOFDNODE"; then
  TRANSPORT="lokaal"
else
  TRANSPORT="internet"
fi

log "Transport:  ${TRANSPORT}"
log "═══════════════════════════════════════════════════"

NAMESPACE="klant/${CONSENT_HASH}"
ZENOH_ENDPOINT="tcp/${HOOFDNODE}:7447"

case "$TRANSPORT" in

  lokaal|internet)
    log "Verbinding via Zenoh: ${ZENOH_ENDPOINT}"

    if command -v zenohd &> /dev/null; then
      zenohd \
        --connect "$ZENOH_ENDPOINT" \
        --id "gast-${CONSENT_HASH}" \
        >> "$LOGFILE" 2>&1 &
      ZENOH_PID=$!
      echo "ZENOH_PID=${ZENOH_PID}" >> "$CONSENT_FILE"
      log "Zenoh actief. PID: ${ZENOH_PID}"
    else
      log "Zenoh niet aanwezig — SSH fallback"
      ssh -N -R "7447:localhost:7447" "reparateur@${HOOFDNODE}" \
        >> "$LOGFILE" 2>&1 &
      SSH_PID=$!
      echo "SSH_PID=${SSH_PID}" >> "$CONSENT_FILE"
      log "SSH tunnel actief. PID: ${SSH_PID}"
    fi
    ;;

  vpn)
    log "VPN modus — verbinding via beveiligde tunnel"
    log "Controleer of VPN actief is op: ${HOOFDNODE}"

    # VPN verbinding controleren
    if ping -c 1 -W 2 "$HOOFDNODE" >> "$LOGFILE" 2>&1; then
      log "Hoofdnode bereikbaar via VPN"
      zenohd \
        --connect "$ZENOH_ENDPOINT" \
        --id "gast-vpn-${CONSENT_HASH}" \
        >> "$LOGFILE" 2>&1 &
      ZENOH_PID=$!
      echo "ZENOH_PID=${ZENOH_PID}" >> "$CONSENT_FILE"
      log "Zenoh via VPN actief. PID: ${ZENOH_PID}"
    else
      log "FOUT: Hoofdnode niet bereikbaar via VPN"
      exit 1
    fi
    ;;

esac

echo "HOOFDNODE=${HOOFDNODE}"       >> "$CONSENT_FILE"
echo "TRANSPORT=${TRANSPORT}"       >> "$CONSENT_FILE"
echo "NAMESPACE=${NAMESPACE}"       >> "$CONSENT_FILE"
echo "ZENOH_ENDPOINT=${ZENOH_ENDPOINT}" >> "$CONSENT_FILE"

log ""
log "Verbinding klaar via ${TRANSPORT}"
log "Namespace: ${NAMESPACE}"
