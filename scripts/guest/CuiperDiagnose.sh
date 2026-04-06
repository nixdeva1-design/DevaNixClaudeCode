#!/usr/bin/env bash
# diagnose.sh — volledige hardware en OS diagnose op gastcomputer
# Vereist: consent.sh eerst uitvoeren
# Output: alle info naar stdout + logfile
# Geen /dev/null — alles is informatie

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
LOGFILE="${LOGDIR}/${TS}-diagnose-${CONSENT_HASH}.log"

log() {
  echo "$1" | tee -a "$LOGFILE"
}

log "═══════════════════════════════════════════════════"
log "CuiperHive Diagnose Rapport"
log "Tijdstip:  $(date '+%Y-%m-%d %H:%M:%S')"
log "Klant:     ${CONSENT_KLANT}"
log "Hash:      ${CONSENT_HASH}"
log "═══════════════════════════════════════════════════"

log ""
log "── OS ──────────────────────────────────────────────"
uname -a | tee -a "$LOGFILE"
cat /etc/os-release 2>&1 | tee -a "$LOGFILE"

log ""
log "── CPU ─────────────────────────────────────────────"
lscpu 2>&1 | tee -a "$LOGFILE"

log ""
log "── GEHEUGEN ────────────────────────────────────────"
free -h 2>&1 | tee -a "$LOGFILE"

log ""
log "── SCHIJVEN ────────────────────────────────────────"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL 2>&1 | tee -a "$LOGFILE"
df -h 2>&1 | tee -a "$LOGFILE"

log ""
log "── SCHIJF GEZONDHEID ───────────────────────────────"
for disk in $(lsblk -dno NAME | grep -v loop); do
  log "Schijf: /dev/${disk}"
  smartctl -H "/dev/${disk}" 2>&1 | tee -a "$LOGFILE"
done

log ""
log "── NETWERK ─────────────────────────────────────────"
ip addr 2>&1 | tee -a "$LOGFILE"
ip route 2>&1 | tee -a "$LOGFILE"

log ""
log "── USB APPARATEN ───────────────────────────────────"
lsusb 2>&1 | tee -a "$LOGFILE"

log ""
log "── PCI APPARATEN ───────────────────────────────────"
lspci 2>&1 | tee -a "$LOGFILE"

log ""
log "── SYSTEEM LOGS (laatste 50 regels) ────────────────"
journalctl -n 50 --no-pager 2>&1 | tee -a "$LOGFILE"

log ""
log "── TEMPERATUUR ─────────────────────────────────────"
sensors 2>&1 | tee -a "$LOGFILE"

log ""
log "═══════════════════════════════════════════════════"
log "Diagnose klaar. Log: ${LOGFILE}"
log "═══════════════════════════════════════════════════"

echo "DIAGNOSE_LOG=${LOGFILE}" >> "$CONSENT_FILE"
