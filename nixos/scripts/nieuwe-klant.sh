#!/usr/bin/env bash
# Nieuwe klant werkplek aanmaken
# Gebruik: nieuwe-klant.sh <klantnaam>
# Maakt aan: /projects/<datum>-<naam>, Gitea repo, PostgreSQL database

set -e

KLANT="${1}"

if [ -z "$KLANT" ]; then
  echo "Gebruik: nieuwe-klant <naam>"
  echo "Voorbeeld: nieuwe-klant jan-bakker"
  exit 1
fi

DATUM=$(date +%Y-%m-%d)
KLANT_DIR="/projects/${DATUM}-${KLANT}"
DB_NAAM="klant_${KLANT//-/_}"
GITEA_USER="reparateur"
GITEA_URL="http://localhost:3000"

if [ -d "$KLANT_DIR" ]; then
  echo "Map bestaat al: $KLANT_DIR"
  cd "$KLANT_DIR"
  exit 0
fi

# Mappenstructuur aanmaken — gescheiden van /lab
mkdir -p "$KLANT_DIR"/{notities,bestanden,scripts,backup,rapport}

# Git repo initialiseren
cd "$KLANT_DIR"
git init -q

# PostgreSQL database aanmaken per klant
echo "Database aanmaken: ${DB_NAAM}"
psql -U reparateur -c "CREATE DATABASE ${DB_NAAM} OWNER reparateur;" 2>/dev/null \
  && echo "Database aangemaakt: ${DB_NAAM}" \
  || echo "Database bestaat al: ${DB_NAAM}"

# Gitea repo aanmaken via API
echo "Gitea repo aanmaken: klant-${KLANT}"
curl -s -X POST "${GITEA_URL}/api/v1/user/repos" \
  -H "Content-Type: application/json" \
  -u "${GITEA_USER}:$(cat ~/.config/gitea/token 2>/dev/null || echo 'token')" \
  -d "{\"name\": \"klant-${KLANT}\", \"description\": \"Klant: ${KLANT} (${DATUM})\", \"private\": true}" \
  > /dev/null && echo "Gitea repo aangemaakt" || echo "Gitea token nog instellen via ~/.config/gitea/token"

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

## Database
- Naam: ${DB_NAAM}
- Verbinding: psql -U reparateur ${DB_NAAM}

## Gitea
- Repo: klant-${KLANT}
- URL: ${GITEA_URL}/${GITEA_USER}/klant-${KLANT}

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

echo ""
echo "Klant werkplek aangemaakt: $KLANT_DIR"
echo "Database: ${DB_NAAM}"
echo "Gitea: ${GITEA_URL}/${GITEA_USER}/klant-${KLANT}"
echo ""
echo "cd $KLANT_DIR"
