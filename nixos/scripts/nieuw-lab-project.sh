#!/usr/bin/env bash
# Nieuw lab project aanmaken
# Gebruik: nieuw-lab-project.sh <projectnaam>
# Maakt aan: /lab/projecten/<naam>, Gitea repo, PostgreSQL database

set -e

PROJECT="${1}"

if [ -z "$PROJECT" ]; then
  echo "Gebruik: nieuw-lab-project <naam>"
  echo "Voorbeeld: nieuw-lab-project mqtt-sensor-test"
  exit 1
fi

DATUM=$(date +%Y-%m-%d)
PROJECT_DIR="/lab/projecten/${PROJECT}"
DB_NAAM="lab_${PROJECT//-/_}"
GITEA_USER="reparateur"
GITEA_URL="http://localhost:3000"

if [ -d "$PROJECT_DIR" ]; then
  echo "Project bestaat al: $PROJECT_DIR"
  cd "$PROJECT_DIR"
  exit 0
fi

# Mappenstructuur aanmaken
mkdir -p "$PROJECT_DIR"/{code,docs,tests,data}

# Git repo initialiseren
cd "$PROJECT_DIR/code"
git init -q
cat > README.md << EOF
# ${PROJECT}
Aangemaakt: ${DATUM}

## Doel


## Notities

EOF
git add README.md
git commit -q -m "init: ${PROJECT}"

# PostgreSQL database aanmaken
echo "Database aanmaken: ${DB_NAAM}"
psql -U reparateur -c "CREATE DATABASE ${DB_NAAM} OWNER reparateur;" 2>/dev/null \
  && echo "Database aangemaakt: ${DB_NAAM}" \
  || echo "Database bestaat al: ${DB_NAAM}"

# Gitea repo aanmaken via API
echo "Gitea repo aanmaken: lab-${PROJECT}"
curl -s -X POST "${GITEA_URL}/api/v1/user/repos" \
  -H "Content-Type: application/json" \
  -u "${GITEA_USER}:$(cat ~/.config/gitea/token 2>/dev/null || echo 'token')" \
  -d "{\"name\": \"lab-${PROJECT}\", \"description\": \"Lab: ${PROJECT}\", \"private\": true}" \
  > /dev/null && echo "Gitea repo aangemaakt" || echo "Gitea token nog instellen via ~/.config/gitea/token"

# Logseq pagina aanmaken
mkdir -p "/data/logseq/pages"
cat > "/data/logseq/pages/lab-${PROJECT}.md" << EOF
# Lab: ${PROJECT}
Aangemaakt: ${DATUM}

## Doel


## Status
- [ ] In ontwikkeling

## Database
- Naam: ${DB_NAAM}
- Verbinding: psql -U reparateur ${DB_NAAM}

## Gitea
- Repo: lab-${PROJECT}
- URL: ${GITEA_URL}/${GITEA_USER}/lab-${PROJECT}
EOF

echo ""
echo "Lab project aangemaakt: $PROJECT_DIR"
echo "Database: ${DB_NAAM}"
echo "Gitea: ${GITEA_URL}/${GITEA_USER}/lab-${PROJECT}"
echo ""
echo "cd $PROJECT_DIR"
