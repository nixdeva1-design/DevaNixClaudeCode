#!/usr/bin/env bash
# verify.sh — Cuiper3MarkovchainProtocol verificatie
# Vergelijkt CuiperNaVerwachtBackup met CuiperVerwachtBackup
# Beslist: vooruit (versie+1) of rollback
# Geen /dev/null — alles gelogd

set -e

LOGFILE="${1}"
VERWACHT="${2}"
NARESULTAAT="${3}"
VERSIENR="${4}"
ROLLBACK_COMMIT="${5}"

TS=$(date +%s)

if [ -z "$LOGFILE" ] || [ ! -f "$LOGFILE" ]; then
  echo "FOUT: logfile niet gevonden: ${LOGFILE}" >&2
  exit 1
fi

echo "=== Cuiper3MarkovchainProtocol Verificatie ==="
echo "Tijdstip:              ${TS}"
echo "CuiperVerwachtBackup:  ${VERWACHT}"
echo "CuiperNaVerwacht:      ${NARESULTAAT}"
echo "Versienr:              ${VERSIENR}"

if [ "${NARESULTAAT}" = "${VERWACHT}" ]; then
  NIEUW_VERSIENR=$((VERSIENR + 1))
  echo "RESULTAAT: MATCH"
  echo "Transitie: CuiperStatusBackup{${VERSIENR}} → CuiperStatusBackup{${NIEUW_VERSIENR}}"

  # Update logfile
  sed -i "s/CuiperNaVerwachtBackup:  PENDING/CuiperNaVerwachtBackup:  ${NARESULTAAT} — MATCH — versie ${NIEUW_VERSIENR}/" "$LOGFILE"
  echo "STATUS: VOORUIT naar versie ${NIEUW_VERSIENR}"

else
  echo "RESULTAAT: MISMATCH"
  echo "Transitie: rollback naar commit ${ROLLBACK_COMMIT}"

  # Update logfile
  sed -i "s/CuiperNaVerwachtBackup:  PENDING/CuiperNaVerwachtBackup:  ${NARESULTAAT} — MISMATCH — rollback naar ${ROLLBACK_COMMIT}/" "$LOGFILE"

  # Rollback uitvoeren
  git -C /home/user/DevaNixClaudeCode checkout "${ROLLBACK_COMMIT}" -- .
  echo "STATUS: ROLLBACK uitgevoerd naar ${ROLLBACK_COMMIT}"
fi

echo "Logfile bijgewerkt: ${LOGFILE}"
