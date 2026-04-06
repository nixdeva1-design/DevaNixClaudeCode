#!/usr/bin/env bash
# log.sh — schrijft trail log naar logs/trail/
# Gebruik: log.sh <volgnr> <hivenr> <hienaam> <vraag> <redenering> <antwoord> <plan> <status_n> <verwacht_n> <rollback>
# Geen /dev/null — alles is informatie

set -e

ULID=$(bash "$(dirname "$0")/CuiperUlid.sh")
TS=$(date +%s)
VOLGNR="${1}"
HIVENR="${2}"
HIENAAM="${3}"
VRAAG="${4}"
REDENERING="${5}"
ANTWOORD="${6}"
PLAN="${7}"
STATUS_N="${8}"
VERWACHT_N="${9}"
ROLLBACK="${10}"

_LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LOG_DIR/../../CuiperConfig.env"
unset _LOG_DIR
LOGDIR="$CUIPER_TRAIL_DIR"
mkdir -p "$LOGDIR"

LOGFILE="${LOGDIR}/${TS}-${ULID}.log"

cat > "$LOGFILE" << EOF
ULID:                    ${ULID}
UnixTimestamp:           ${TS}
Volgnr:                  ${VOLGNR}
Met:                     CuiperHiveNr ${HIVENR} — ${HIENAAM}
Hive:                    ${CUIPER_BRANCH}
Vraagprompt:             ${VRAAG}
Redenering:              ${REDENERING}
Antwoordprompt:          ${ANTWOORD}
Plan:                    ${PLAN}
CuiperStatusBackup:      ${STATUS_N}
CuiperVerwachtBackup:    ${VERWACHT_N}
Rollbackpunt:            ${ROLLBACK}
CuiperNaVerwachtBackup:  PENDING
EOF

echo "LOG: ${LOGFILE}"
echo "ULID: ${ULID}"
