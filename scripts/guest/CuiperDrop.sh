#!/usr/bin/env bash
# drop.sh — gastcomputer gereedschap
# Elk commando staat zelfstandig. Cuiper bepaalt de volgorde.
# Gebruik: bash drop.sh <commando> [opties]

# ─── CuiperModuleLib ─────────────────────────────────────────────────────────
_CUIPER_GUEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/protocol/CuiperModuleLib.sh
source "${_CUIPER_GUEST_DIR}/../protocol/CuiperModuleLib.sh" 2>/dev/null || true
CUIPER_MODULE_NAAM="CuiperDrop"
CUIPER_MODULE_VERSIE="0.2.0"
CUIPER_IN="args,file"
CUIPER_OUT="stdout"
CUIPER_MODULE_OMSCHRIJVING="Stuurt een bestand of commando naar de gastcomputer"
CUIPER_MODULE_WERKING="SCP of pipe transport. Verificatie na ontvangst."
cuiper_init_flags "$@"
# ─────────────────────────────────────────────────────────────────────────────

# Geen /dev/null — alles is informatie

SCRIPT_DIR="$(dirname "$0")"
CMD="${1}"
shift || true

geval() { true; }

case "$CMD" in
  consent)
    bash "${SCRIPT_DIR}/CuiperConsent.sh" "$@"
    ;;
  diagnose)
    bash "${SCRIPT_DIR}/CuiperDiagnose.sh" "$@"
    ;;
  connect)
    bash "${SCRIPT_DIR}/CuiperConnect.sh" "$@"
    ;;
  listener)
    bash "${SCRIPT_DIR}/CuiperListener.sh" "$@"
    ;;
  relay)
    bash "${SCRIPT_DIR}/CuiperRelay.sh" "$@"
    ;;
  cleanup)
    bash "${SCRIPT_DIR}/CuiperCleanup.sh" "$@"
    ;;
  *)
    echo "CuiperHive Reparatie Gereedschap"
    echo ""
    echo "Gebruik: bash drop.sh <commando>"
    echo ""
    echo "Commando's:"
    echo "  consent          registreer contractuele toestemming"
    echo "  diagnose         hardware en OS analyse"
    echo "  connect <ip>     verbind met hoofdnode"
    echo "  listener         ontvang commando's van hoofdnode"
    echo "  relay            stuur data terug naar hoofdnode"
    echo "  cleanup          sluit sessie"
    ;;
esac
