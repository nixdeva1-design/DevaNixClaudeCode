#!/usr/bin/env bash
# drop.sh — gastcomputer gereedschap
# Elk commando staat zelfstandig. Cuiper bepaalt de volgorde.
# Gebruik: bash drop.sh <commando> [opties]
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
