#!/usr/bin/env bash
# CuiperSteward — beheert continuïteit van ontwerpen en staat
# Verschil met Sentinel:
#   Sentinel = bewaakt en redt bij gevaar (reactief)
#   Steward  = beheert en verzorgt de kennis actief (proactief)
#
# Taken:
#   1. Sessie openen — laad laatste CuiperStapNr
#   2. Ontwerpen controleren — zijn alle documenten aanwezig?
#   3. Sessie sluiten — sla alles op met trail log
#   4. Herstel na onderbreking — wat was de laatste staat?
# Geen /dev/null — alles is informatie

set -e

# ─── Centrale config — geen hardcoded paden ───────────────────────────────
_STEWARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_STEWARD_DIR/../../CuiperConfig.env"
unset _STEWARD_DIR

REPO="$CUIPER_REPO"
LOGDIR="$CUIPER_TRAIL_DIR"
BRANCH="$CUIPER_BRANCH"

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
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] STEWARD: $1" | tee -a "${LOGDIR}/steward.log"
}

# ─── Laatste CuiperStapNr lezen uit git log ───────────────────────────────
lees_stap_nr() {
  cd "$REPO"
  git log --oneline --all | grep -oP 'CuiperStapNr \K[0-9]+' | sort -n | tail -1 || echo "0"
}

# ─── Verplichte ontwerp bestanden controleren ─────────────────────────────
controleer_ontwerpen() {
  local ONTBREKEND=0

  declare -A VERPLICHT=(
    ["CLAUDE.md"]="Protocol en hive definitie"
    ["ontologie/CuiperOerOntologie.md"]="Oer ontologie definitie"
    ["nixos/db/001_CuiperPortConflictRegistry.sql"]="Poort conflict kennisdb"
    ["nixos/db/002_CuiperOerOntologie.sql"]="Ontologie SQL schema"
    ["nixos/flake.nix"]="NixOS flake"
    ["nixos/modules/CuiperPorts.nix"]="Centrale poortregistry"
    ["scripts/protocol/CuiperUlid.sh"]="ULID generator"
    ["scripts/protocol/CuiperLog.sh"]="Trail logger"
    ["scripts/protocol/CuiperVerify.sh"]="Markov verificatie"
  )

  log "Ontwerpen controleren..."

  for PAD in "${!VERPLICHT[@]}"; do
    if [ ! -f "${REPO}/${PAD}" ]; then
      log "ONTBREEKT: ${PAD} — ${VERPLICHT[$PAD]}"
      ONTBREKEND=$((ONTBREKEND + 1))
    else
      log "OK: ${PAD}"
    fi
  done

  if [ $ONTBREKEND -gt 0 ]; then
    log "WAARSCHUWING: ${ONTBREKEND} verplichte bestanden ontbreken"
    return 1
  fi

  log "Alle ontwerpen aanwezig."
  return 0
}

# ─── Sessie openen ────────────────────────────────────────────────────────
sessie_open() {
  local ULID=$(ulid)
  local TS=$(date +%s)
  local STAP_NR=$(lees_stap_nr)
  local COMMIT=$(git -C "$REPO" log -1 --format="%H")

  log "═══════════════════════════════════════"
  log "CuiperSteward sessie geopend"
  log "ULID: ${ULID}"
  log "Tijdstip: $(date '+%Y-%m-%d %H:%M:%S')"
  log "Laatste CuiperStapNr: ${STAP_NR}"
  log "Laatste commit: ${COMMIT}"
  log "Branch: ${BRANCH}"

  controleer_ontwerpen

  cat > "${LOGDIR}/${TS}-sessie-open-${ULID}.log" << EOF
ULID:            ${ULID}
UnixTimestamp:   ${TS}
CuiperStapNr:    ${STAP_NR}
Type:            SESSIE_OPEN
Commit:          ${COMMIT}
Branch:          ${BRANCH}
Steward:         actief
Sentinel:        $(pgrep -f CuiperSentinel.sh > /dev/null && echo "actief" || echo "niet actief")
EOF

  echo "STEWARD_ULID=${ULID}" > "${REPO}/.steward_sessie"
  echo "STEWARD_STAP=${STAP_NR}" >> "${REPO}/.steward_sessie"
  echo "STEWARD_TS=${TS}" >> "${REPO}/.steward_sessie"

  log "Sessie klaar. Volgende CuiperStapNr: $((STAP_NR + 1))"
  log "═══════════════════════════════════════"
}

# ─── Sessie sluiten ───────────────────────────────────────────────────────
sessie_sluit() {
  local REDEN="${1:-normaal}"
  local ULID=$(ulid)
  local TS=$(date +%s)
  local STAP_NR=$(lees_stap_nr)

  log "Sessie sluiten. Reden: ${REDEN}"

  # Laatste wijzigingen opslaan
  cd "$REPO"
  if ! git diff --quiet || ! git diff --cached --quiet; then
    git add -A
    git commit -m "CuiperSteward: sessie gesloten
Reden: ${REDEN}
CuiperStapNr: ${STAP_NR}
ULID: ${ULID}

https://claude.ai/code/session_01LwAQ3fvpdvRMMTi8o92pKu"
    git push
    log "Wijzigingen opgeslagen en gepusht."
  fi

  cat >> "${LOGDIR}/${TS}-sessie-sluit-${ULID}.log" << EOF
ULID:            ${ULID}
UnixTimestamp:   ${TS}
CuiperStapNr:    ${STAP_NR}
Type:            SESSIE_SLUIT
Reden:           ${REDEN}
Commit:          $(git -C "$REPO" log -1 --format="%H")
EOF

  rm -f "${REPO}/.steward_sessie"
  log "Sessie gesloten. Trail opgeslagen."
}

# ─── Herstel na onderbreking ──────────────────────────────────────────────
herstel() {
  log "Herstel na onderbreking..."

  cd "$REPO"
  git fetch origin "$BRANCH" >> "${LOGDIR}/steward.log" 2>&1

  local LOKAAL=$(git rev-parse HEAD)
  local REMOTE=$(git rev-parse "origin/${BRANCH}")

  if [ "$LOKAAL" != "$REMOTE" ]; then
    log "Verschil lokaal/remote. Lokaal: ${LOKAAL} Remote: ${REMOTE}"
    git pull origin "$BRANCH" >> "${LOGDIR}/steward.log" 2>&1
    log "Gesynchroniseerd."
  else
    log "Lokaal en remote gesynchroniseerd."
  fi

  controleer_ontwerpen
  sessie_open
}

# ─── Hoofd ────────────────────────────────────────────────────────────────
case "${1:-open}" in
  open)    sessie_open ;;
  sluit)   sessie_sluit "${2:-normaal}" ;;
  herstel) herstel ;;
  check)   controleer_ontwerpen ;;
  *)
    echo "Gebruik: steward.sh <open|sluit|herstel|check>"
    ;;
esac
