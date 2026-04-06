#!/usr/bin/env bash
# drop.sh — Linux/Mac entry point voor gastcomputer
# Gebruik: bash drop.sh <hoofdnode-ip>
# Voert consent → diagnose → connect → listener uit in volgorde
# Geen /dev/null — alles is informatie

set -e

HOOFDNODE_IP="${1}"
SCRIPT_DIR="$(dirname "$0")"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║              CuiperHive Reparatie Systeem                ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

if [ -z "$HOOFDNODE_IP" ]; then
  echo "Gebruik: bash drop.sh <hoofdnode-ip>"
  echo "Vraag het IP adres aan de reparateur."
  exit 1
fi

# Stap 1 — Toestemming
echo "Stap 1/4: Toestemming"
bash "${SCRIPT_DIR}/consent.sh"

# Stap 2 — Diagnose
echo ""
echo "Stap 2/4: Diagnose van deze computer"
bash "${SCRIPT_DIR}/diagnose.sh"

# Stap 3 — Verbinding
echo ""
echo "Stap 3/4: Verbinding met reparateur"
bash "${SCRIPT_DIR}/connect.sh" "$HOOFDNODE_IP"

# Stap 4 — Listener starten
echo ""
echo "Stap 4/4: Wachten op reparateur"
bash "${SCRIPT_DIR}/listener.sh"

# Na sessie — cleanup
echo ""
echo "Sessie klaar. Opruimen..."
bash "${SCRIPT_DIR}/cleanup.sh"
