#!/usr/bin/env bash
# agent.sh — CuiperHive agent op gastcomputer
# Voert standaard sequentie uit: diagnose → connect → listener
# Implementeert Cuiper3MarkovchainProtocol volledig:
#   trail, backup, verificatie, rollback
# Cuiper bepaalt wanneer agent gestart wordt — agent bepaalt de rest
# Geen /dev/null — alles is informatie

set -e

SCRIPT_DIR="$(dirname "$0")"
HOOFDNODE_IP="${1}"
LOGDIR="${SCRIPT_DIR}/../../logs/trail"
mkdir -p "$LOGDIR"

# ─── ULID genereren ───────────────────────────────────────────
ulid() {
  local ENCODING="0123456789ABCDEFGHJKMNPQRSTVWXYZ"
  local ts_ms n ulid_ts ulid_rand
  ts_ms=$(date +%s%3N)
  n=$ts_ms
  ulid_ts=""
  for i in $(seq 1 10); do
    ulid_ts="${ENCODING:$((n % 32)):1}${ulid_ts}"
    n=$((n / 32))
  done
  ulid_rand=""
  for i in $(seq 1 16); do
    ulid_rand="${ulid_rand}${ENCODING:$((RANDOM % 32)):1}"
  done
  echo "${ulid_ts}${ulid_rand}"
}

# ─── Trail schrijven ──────────────────────────────────────────
trail() {
  local STAP="$1" STATUS="$2" VERWACHT="$3" NARESULTAAT="$4" ROLLBACK="$5"
  local ULID TS LOGFILE
  ULID=$(ulid)
  TS=$(date +%s)
  LOGFILE="${LOGDIR}/${TS}-agent-stap${STAP}-${ULID}.log"

  cat > "$LOGFILE" << EOF
ULID:                    ${ULID}
UnixTimestamp:           ${TS}
CuiperStapNr:            ${STAP}
Met:                     CuiperHiveNr 1 — Cuiper
Hive:                    claude/linux-usb-dual-boot-Hsk67
Agent:                   guest/agent.sh
CuiperStatusBackup:      ${STATUS}
CuiperVerwachtBackup:    ${VERWACHT}
Rollbackpunt:            ${ROLLBACK}
CuiperNaVerwachtBackup:  ${NARESULTAAT}
EOF

  echo "TRAIL: ${LOGFILE}"
}

# ─── Markov verificatie ───────────────────────────────────────
markov() {
  local STAP="$1" STATUS="$2" VERWACHT="$3" NARESULTAAT="$4" ROLLBACK="$5"

  trail "$STAP" "$STATUS" "$VERWACHT" "$NARESULTAAT" "$ROLLBACK"

  if [ "$NARESULTAAT" = "$VERWACHT" ]; then
    echo "MARKOV: MATCH — stap ${STAP} geslaagd"
    return 0
  else
    echo "MARKOV: MISMATCH — stap ${STAP} mislukt"
    echo "MARKOV: verwacht=${VERWACHT} werkelijk=${NARESULTAAT}"
    echo "MARKOV: rollback naar ${ROLLBACK}"
    return 1
  fi
}

# ─── Script uitvoeren met verificatie ─────────────────────────
voer_uit() {
  local NAAM="$1"
  local SCRIPT="$2"
  shift 2
  local VERWACHT="OK:${NAAM}"
  local STATUS="VOOR:${NAAM}"
  local ROLLBACK="13b1d1f"
  local UITVOER NARESULTAAT

  echo ""
  echo "══ Agent: ${NAAM} ══"

  UITVOER=$(bash "$SCRIPT" "$@" 2>&1)
  local EXIT_CODE=$?

  echo "$UITVOER"

  if [ $EXIT_CODE -eq 0 ]; then
    NARESULTAAT="OK:${NAAM}"
  else
    NARESULTAAT="FOUT:${NAAM}:exit${EXIT_CODE}"
  fi

  if ! markov "$CUIPER_STAP" "$STATUS" "$VERWACHT" "$NARESULTAAT" "$ROLLBACK"; then
    echo "Agent stopt wegens mismatch op stap: ${NAAM}"
    trail "$CUIPER_STAP" "$STATUS" "$VERWACHT" "ROLLBACK:${NAAM}" "$ROLLBACK"
    exit 1
  fi

  CUIPER_STAP=$((CUIPER_STAP + 1))
}

# ─── Hoofdprogramma ───────────────────────────────────────────
if [ -z "$HOOFDNODE_IP" ]; then
  echo "Gebruik: bash agent.sh <hoofdnode-ip>"
  exit 1
fi

CUIPER_STAP=100  # agent stapnummers beginnen bij 100

echo "CuiperHive Agent gestart"
echo "Hoofdnode: ${HOOFDNODE_IP}"
echo "Protocol: Cuiper3MarkovchainProtocol"
echo ""

# Standaard sequentie — agent stuurt dit altijd
# Cuiper bepaalt wanneer agent gestart wordt
voer_uit "diagnose"  "${SCRIPT_DIR}/CuiperDiagnose.sh"
voer_uit "connect"   "${SCRIPT_DIR}/CuiperConnect.sh"  "$HOOFDNODE_IP"
voer_uit "listener"  "${SCRIPT_DIR}/CuiperListener.sh"

echo ""
echo "Agent sequentie klaar. Trail geschreven naar: ${LOGDIR}"
