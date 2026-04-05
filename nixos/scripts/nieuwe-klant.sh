#!/usr/bin/env bash
# Nieuwe klant werkplek aanmaken
# Gebruik: nieuwe-klant.sh <klantnaam>

set -e

KLANT="${1}"

if [ -z "$KLANT" ]; then
  echo "Gebruik: nieuwe-klant <naam>"
  echo "Voorbeeld: nieuwe-klant jan-bakker"
  exit 1
fi

DATUM=$(date +%Y-%m-%d)
KLANT_DIR="/projects/${DATUM}-${KLANT}"

if [ -d "$KLANT_DIR" ]; then
  echo "Map bestaat al: $KLANT_DIR"
  cd "$KLANT_DIR"
  exit 0
fi

# Mappenstructuur aanmaken
mkdir -p "$KLANT_DIR"/{notities,bestanden,scripts,backup,rapport}

# Git repo initialiseren
cd "$KLANT_DIR"
git init -q

# Logseq pagina aanmaken
mkdir -p "/data/logseq/pages"
cat > "/data/logseq/pages/${KLANT}.md" << EOF
# Klant: ${KLANT}
Aangemaakt: ${DATUM}

## Apparaat
- Type:
- OS:
- Serienummer:

## Probleem
- Omschrijving:

## Diagnose
-

## Uitgevoerde acties
-

## Status
- [ ] In behandeling
- [ ] Opgelost
- [ ] Terugkoppeling verstuurd
EOF

# Rapport template
cat > "$KLANT_DIR/rapport/rapport.md" << EOF
# Reparatierapport
**Klant:** ${KLANT}
**Datum:** ${DATUM}

## Bevindingen


## Uitgevoerd werk


## Aanbevelingen


## Kosten
EOF

echo "Klant werkplek aangemaakt: $KLANT_DIR"
echo "Logseq pagina aangemaakt: /data/logseq/pages/${KLANT}.md"
echo ""
echo "Open map: cd $KLANT_DIR"
