#!/usr/bin/env bash
# CuiperBacklogPlanner.sh — beheert de CuiperHive backlog
# Leest openstaande taken uit trail logs en CLAUDE.md
# Schrijft gesedimenteerde backlog naar backlog/CuiperBacklog.md
# Geen /dev/null — alles is informatie
#
# Gebruik:
#   CuiperBacklogPlanner.sh toon         toon huidige backlog
#   CuiperBacklogPlanner.sh toevoeg      voeg taak toe
#   CuiperBacklogPlanner.sh klaar <id>   markeer taak klaar
#   CuiperBacklogPlanner.sh sync         lees trail logs en update backlog

set -e

REPO="/home/user/DevaNixClaudeCode"
BACKLOG_DIR="${REPO}/backlog"
BACKLOG_FILE="${BACKLOG_DIR}/CuiperBacklog.md"
LOGDIR="${REPO}/logs/trail"
BRANCH="claude/linux-usb-dual-boot-Hsk67"

mkdir -p "$BACKLOG_DIR"

ulid() {
  local ENC="0123456789ABCDEFGHJKMNPQRSTVWXYZ"
  local ts n t r
  ts=$(date +%s%3N); n=$ts; t=""
  for i in $(seq 1 10); do t="${ENC:$((n%32)):1}${t}"; n=$((n/32)); done
  r=""
  for i in $(seq 1 16); do r="${r}${ENC:$((RANDOM%32)):1}"; done
  echo "${t}${r}"
}

stap_nr() {
  git -C "$REPO" log --oneline --all | grep -oP 'CuiperStapNr \K[0-9]+' | sort -n | tail -1 || echo "0"
}

# ─── Initialiseer backlog bestand als het niet bestaat ────────────────────
init_backlog() {
  if [ ! -f "$BACKLOG_FILE" ]; then
    cat > "$BACKLOG_FILE" << EOF
# CuiperBacklog
# Branch: ${BRANCH}
# Geen /dev/null — alle taken worden gesedimenteerd

## Formaat
\`\`\`
| ID | Status | Prioriteit | Taak | CuiperStapNr | ULID | Aangemaakt |
\`\`\`

Status: OPEN | BEZIG | KLAAR | GEBLOKKEERD | GESEDIMENTEERD
Prioriteit: KRITIEK | HOOG | MEDIUM | LAAG

## Backlog

| ID | Status | Prioriteit | Taak | StapNr | ULID |
|----|--------|------------|------|--------|------|
EOF
    echo "Backlog geïnitialiseerd: ${BACKLOG_FILE}"
  fi
}

# ─── Toon backlog ─────────────────────────────────────────────────────────
toon() {
  init_backlog
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "CuiperBacklog — $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Branch: ${BRANCH}"
  echo "Laatste CuiperStapNr: $(stap_nr)"
  echo "═══════════════════════════════════════════════════════"
  echo ""

  # OPEN taken
  echo "── OPEN ──────────────────────────────────────────────"
  grep "| OPEN " "$BACKLOG_FILE" || echo "  (geen)"

  echo ""
  echo "── BEZIG ─────────────────────────────────────────────"
  grep "| BEZIG " "$BACKLOG_FILE" || echo "  (geen)"

  echo ""
  echo "── GEBLOKKEERD ───────────────────────────────────────"
  grep "| GEBLOKKEERD " "$BACKLOG_FILE" || echo "  (geen)"

  echo ""
  echo "── KLAAR (laatste 5) ─────────────────────────────────"
  grep "| KLAAR " "$BACKLOG_FILE" | tail -5 || echo "  (geen)"

  echo ""
}

# ─── Taak toevoegen ───────────────────────────────────────────────────────
toevoeg() {
  init_backlog

  read -p "Taak omschrijving: " TAAK
  echo "Prioriteit: 1) KRITIEK  2) HOOG  3) MEDIUM  4) LAAG"
  read -p "Keuze [1-4]: " PRIO_KEUZE

  case "$PRIO_KEUZE" in
    1) PRIO="KRITIEK" ;;
    2) PRIO="HOOG" ;;
    3) PRIO="MEDIUM" ;;
    *) PRIO="LAAG" ;;
  esac

  local ID=$(ulid)
  local STAP=$(stap_nr)
  local DATUM=$(date '+%Y-%m-%d')

  # Toevoegen aan backlog tabel
  echo "| ${ID:0:8} | OPEN | ${PRIO} | ${TAAK} | ${STAP} | ${ID} |" >> "$BACKLOG_FILE"

  echo "Taak toegevoegd: [${ID:0:8}] ${PRIO} — ${TAAK}"

  # Commit en push
  git -C "$REPO" add "$BACKLOG_FILE"
  git -C "$REPO" commit -m "CuiperBacklog: taak toegevoegd [${ID:0:8}] ${TAAK}"
  git -C "$REPO" push
}

# ─── Taak markeren als klaar ──────────────────────────────────────────────
klaar() {
  local TAAK_ID="$1"
  [ -z "$TAAK_ID" ] && echo "Gebruik: CuiperBacklogPlanner.sh klaar <id>" && exit 1

  if grep -q "$TAAK_ID" "$BACKLOG_FILE"; then
    sed -i "s/| OPEN \(.*${TAAK_ID}\)/| KLAAR \1/" "$BACKLOG_FILE"
    sed -i "s/| BEZIG \(.*${TAAK_ID}\)/| KLAAR \1/" "$BACKLOG_FILE"
    echo "Taak gemarkeerd als KLAAR: ${TAAK_ID}"

    git -C "$REPO" add "$BACKLOG_FILE"
    git -C "$REPO" commit -m "CuiperBacklog: taak klaar [${TAAK_ID}]"
    git -C "$REPO" push
  else
    echo "Taak niet gevonden: ${TAAK_ID}"
  fi
}

# ─── Sync met trail logs ──────────────────────────────────────────────────
# Leest sessie-einde logs en voegt openstaande taken automatisch toe
sync() {
  init_backlog
  echo "Synchroniseren met trail logs..."

  # Lees sessie-einde logs voor openstaande taken
  for LOG in "${LOGDIR}"/*sessie-einde*.log; do
    [ -f "$LOG" ] || continue

    # Extract openstaande taken uit log
    if grep -q "Openstaand bij sluiten:" "$LOG"; then
      STAP=$(grep "CuiperStapNr:" "$LOG" | head -1 | awk '{print $2}')
      ULID_REF=$(grep "ULID:" "$LOG" | head -1 | awk '{print $2}')

      while IFS= read -r REGEL; do
        TAAK=$(echo "$REGEL" | sed 's/^[[:space:]]*-[[:space:]]*//')
        [ -z "$TAAK" ] && continue

        # Voeg alleen toe als nog niet in backlog
        if ! grep -q "$TAAK" "$BACKLOG_FILE" 2>/dev/null; then
          local ID=$(ulid)
          echo "| ${ID:0:8} | OPEN | HOOG | ${TAAK} | ${STAP} | ${ULID_REF} |" >> "$BACKLOG_FILE"
          echo "Taak gesynchroniseerd: ${TAAK}"
        fi
      done < <(sed -n '/Openstaand bij sluiten:/,/^[A-Z]/p' "$LOG" | grep "^  -")
    fi
  done

  git -C "$REPO" add "$BACKLOG_FILE"
  git -C "$REPO" diff --cached --quiet || git -C "$REPO" commit -m "CuiperBacklog: gesynchroniseerd met trail logs"
  git -C "$REPO" push

  echo "Sync klaar."
  toon
}

# ─── Hoofd ────────────────────────────────────────────────────────────────
case "${1:-toon}" in
  toon)    toon ;;
  toevoeg) toevoeg ;;
  klaar)   klaar "$2" ;;
  sync)    sync ;;
  *)
    echo "Gebruik: CuiperBacklogPlanner.sh <toon|toevoeg|klaar|sync>"
    ;;
esac
