#!/usr/bin/env bash
# consent.sh — klant bevestigt toestemming voor remote toegang
# ALTIJD als eerste uitvoeren. Zonder toestemming start niets.
# Output: consent hash + log naar trail
# Geen /dev/null — alles is informatie

set -e

# ─── CuiperModuleLib ─────────────────────────────────────────────────────────
_CUIPER_GUEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/protocol/CuiperModuleLib.sh
source "${_CUIPER_GUEST_DIR}/../protocol/CuiperModuleLib.sh" 2>/dev/null || true
CUIPER_MODULE_NAAM="CuiperConsent"
CUIPER_MODULE_VERSIE="0.2.0"
CUIPER_IN="stdin"
CUIPER_OUT="file,stdout"
CUIPER_MODULE_OMSCHRIJVING="Vraagt toestemming van gastgebruiker voor CuiperAgent operaties"
CUIPER_MODULE_WERKING="Toont wat er uitgevoerd wordt. Wacht op expliciete ja/nee. Logt beslissing."
cuiper_init_flags "$@"
# ─────────────────────────────────────────────────────────────────────────────


CONSENT_LOG="$(dirname "$0")/../../logs/trail/consent.log"
mkdir -p "$(dirname "$CONSENT_LOG")"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║         CuiperHive Reparatie — Toestemmingsformulier     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "De reparateur vraagt toestemming om op afstand op deze"
echo "computer te werken voor:"
echo ""
echo "  - Diagnose van hardware en software"
echo "  - Installatie of reparatie van programma's"
echo "  - Bekijken van systeeminformatie"
echo ""
echo "Wat NIET gebeurt:"
echo "  - Persoonlijke bestanden worden niet gelezen"
echo "  - Geen wachtwoorden of privédata"
echo "  - Scripts verwijderen zichzelf na de sessie"
echo ""

read -p "Uw volledige naam: " KLANT_NAAM
read -p "Datum (Enter = vandaag): " DATUM
DATUM="${DATUM:-$(date +%Y-%m-%d)}"

echo ""
echo "Geeft u toestemming aan de reparateur om op afstand"
echo "op deze computer te werken? (ja/nee)"
read -p "> " ANTWOORD

if [ "${ANTWOORD,,}" != "ja" ]; then
  echo "Geen toestemming gegeven. Script stopt."
  echo "$(date +%s) GEWEIGERD ${KLANT_NAAM}" >> "$CONSENT_LOG"
  exit 1
fi

TS=$(date +%s)
HASH=$(echo "${KLANT_NAAM}${TS}${DATUM}" | sha256sum | cut -c1-16)

cat >> "$CONSENT_LOG" << EOF
═══════════════════════════════════════
Tijdstip:    $(date '+%Y-%m-%d %H:%M:%S')
UnixStamp:   ${TS}
Klant:       ${KLANT_NAAM}
Datum:       ${DATUM}
Toestemming: JA
Hash:        ${HASH}
OS:          $(uname -a)
Hostname:    $(hostname)
═══════════════════════════════════════
EOF

echo ""
echo "Toestemming geregistreerd. Hash: ${HASH}"
echo "CONSENT_HASH=${HASH}" > "$(dirname "$0")/.consent"
echo "CONSENT_TS=${TS}" >> "$(dirname "$0")/.consent"
echo "CONSENT_KLANT=${KLANT_NAAM}" >> "$(dirname "$0")/.consent"
echo ""
echo "Sessie gestart. De reparateur kan nu beginnen."
