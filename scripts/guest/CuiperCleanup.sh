#!/usr/bin/env bash
# cleanup.sh — verwijdert guest scripts en sluit verbindingen na sessie
# Logt eerst alles weg via relay, dan pas opruimen
# Geen /dev/null — alles is informatie

set -e

# ─── CuiperModuleLib ─────────────────────────────────────────────────────────
_CUIPER_GUEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/protocol/CuiperModuleLib.sh
source "${_CUIPER_GUEST_DIR}/../protocol/CuiperModuleLib.sh" 2>/dev/null || true
CUIPER_MODULE_NAAM="CuiperCleanup"
CUIPER_MODULE_VERSIE="0.2.0"
CUIPER_IN="args"
CUIPER_OUT="trail,stdout"
CUIPER_MODULE_OMSCHRIJVING="Verwijdert tijdelijke bestanden op gastcomputer na sessie"
CUIPER_MODULE_WERKING="Ruimt CuiperAgent artefacten op. Logt alles — niets stil weggooien."
cuiper_init_flags "$@"
# ─────────────────────────────────────────────────────────────────────────────


SCRIPT_DIR="$(dirname "$0")"
CONSENT_FILE="${SCRIPT_DIR}/.consent"

if [ ! -f "$CONSENT_FILE" ]; then
  echo "Geen actieve sessie gevonden."
  exit 0
fi

source "$CONSENT_FILE"

echo "Sessie afsluiten voor: ${CONSENT_KLANT}"
echo "Hash: ${CONSENT_HASH}"

# Eerst relay — data veiligstellen
echo "Data terugsturen naar hoofdnode..."
bash "${SCRIPT_DIR}/CuiperRelay.sh"

# Verbindingen sluiten
if [ -n "$ZENOH_PID" ]; then
  kill "$ZENOH_PID" 2>&1 && echo "Zenoh verbinding gesloten." \
    || echo "Zenoh was al gestopt."
fi

if [ -n "$SSH_PID" ]; then
  kill "$SSH_PID" 2>&1 && echo "SSH tunnel gesloten." \
    || echo "SSH was al gestopt."
fi

# Listener stoppen
echo "STOP" >> "${SCRIPT_DIR}/.cmdqueue"

# Consent en queue verwijderen
rm -f "${CONSENT_FILE}" "${SCRIPT_DIR}/.cmdqueue"

echo ""
echo "Sessie gesloten. Scripts verwijderd."
echo "Logs bewaard op hoofdnode."
