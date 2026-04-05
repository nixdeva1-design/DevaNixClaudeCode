#!/usr/bin/env bash
# Snapshot beheer — maak, bekijk en herstel snapshots
# Gebruik:
#   snapshot.sh maak   klant jan-bakker
#   snapshot.sh maak   lab   mqtt-sensor-test
#   snapshot.sh maak   airgap test-sessie-1
#   snapshot.sh lijst
#   snapshot.sh herstel klant jan-bakker 2026-04-05T14:30
#   snapshot.sh verwijder klant jan-bakker 2026-04-05T14:30

set -e

ACTIE="${1}"
TYPE="${2}"       # klant | lab | airgap
NAAM="${3}"       # naam van klant/project
TIJDSTIP="${4}"   # voor herstel

SNAPSHOT_BASE="/data/snapshots"
TIJDSTIP_NU=$(date +%Y-%m-%dT%H:%M)

# Bronmap bepalen op basis van type
bronmap() {
  case "$1" in
    klant)  echo "/projects/${NAAM}" ;;
    lab)    echo "/lab/projecten/${NAAM}" ;;
    airgap) echo "/airgap/tests/${NAAM}" ;;
    *)      echo "Onbekend type: $1"; exit 1 ;;
  esac
}

snapshot_map() {
  echo "${SNAPSHOT_BASE}/${TYPE}s/${NAAM}/${TIJDSTIP:-$TIJDSTIP_NU}"
}

geval "$ACTIE" in

  maak)
    [ -z "$TYPE" ] || [ -z "$NAAM" ] && echo "Gebruik: snapshot.sh maak <type> <naam>" && exit 1

    BRON=$(bronmap "$TYPE")
    DOEL=$(snapshot_map)

    [ ! -d "$BRON" ] && echo "Niet gevonden: $BRON" && exit 1

    mkdir -p "$(dirname "$DOEL")"

    # Btrfs snapshot als mogelijk, anders rsync
    if btrfs subvolume show "$BRON" &>/dev/null; then
      btrfs subvolume snapshot -r "$BRON" "$DOEL"
      echo "Btrfs snapshot: $DOEL"
    else
      rsync -a --link-dest="$BRON" "$BRON/" "$DOEL/"
      echo "Rsync snapshot: $DOEL"
    fi

    # PostgreSQL dump meenemen
    DB_NAAM="${TYPE}_${NAAM//-/_}"
    if psql -U reparateur -lqt | grep -q "$DB_NAAM"; then
      pg_dump -U reparateur "$DB_NAAM" > "${DOEL}.sql"
      echo "Database dump: ${DOEL}.sql"
    fi

    echo "Snapshot klaar: $TIJDSTIP_NU"
    ;;

  lijst)
    echo "=== Beschikbare snapshots ==="
    for type in klanten labs; do
      DIR="${SNAPSHOT_BASE}/${type}"
      [ -d "$DIR" ] || continue
      echo ""
      echo "── ${type} ──"
      find "$DIR" -mindepth 2 -maxdepth 2 -type d | sort | while read -r snap; do
        NAAM=$(basename "$(dirname "$snap")")
        TS=$(basename "$snap")
        SIZE=$(du -sh "$snap" 2>/dev/null | cut -f1)
        echo "  ${NAAM} @ ${TS} (${SIZE})"
      done
    done
    ;;

  herstel)
    [ -z "$TYPE" ] || [ -z "$NAAM" ] || [ -z "$TIJDSTIP" ] && \
      echo "Gebruik: snapshot.sh herstel <type> <naam> <tijdstip>" && exit 1

    BRON=$(bronmap "$TYPE")
    SNAP="${SNAPSHOT_BASE}/${TYPE}s/${NAAM}/${TIJDSTIP}"

    [ ! -d "$SNAP" ] && echo "Snapshot niet gevonden: $SNAP" && exit 1

    # Huidige staat eerst bewaren
    echo "Huidige staat bewaren voor herstel..."
    BACKUP="${SNAPSHOT_BASE}/${TYPE}s/${NAAM}/voor-herstel-${TIJDSTIP_NU}"
    rsync -a "$BRON/" "$BACKUP/"
    echo "Backup: $BACKUP"

    # Herstel bestanden
    rsync -a --delete "$SNAP/" "$BRON/"
    echo "Bestanden hersteld van: $SNAP"

    # Herstel database als dump beschikbaar
    DB_NAAM="${TYPE}_${NAAM//-/_}"
    SQL_DUMP="${SNAP}.sql"
    if [ -f "$SQL_DUMP" ]; then
      psql -U reparateur -c "DROP DATABASE IF EXISTS ${DB_NAAM}_herstel;"
      psql -U reparateur -c "CREATE DATABASE ${DB_NAAM}_herstel OWNER reparateur;"
      psql -U reparateur "${DB_NAAM}_herstel" < "$SQL_DUMP"
      echo "Database hersteld als: ${DB_NAAM}_herstel"
      echo "Vergelijk met: psql -U reparateur ${DB_NAAM}_herstel"
    fi

    echo ""
    echo "Herstel klaar. Origineel bewaard in: $BACKUP"
    ;;

  verwijder)
    SNAP="${SNAPSHOT_BASE}/${TYPE}s/${NAAM}/${TIJDSTIP}"
    [ ! -d "$SNAP" ] && echo "Niet gevonden: $SNAP" && exit 1
    rm -rf "$SNAP" "${SNAP}.sql"
    echo "Verwijderd: $SNAP"
    ;;

  *)
    echo "Gebruik: snapshot.sh <maak|lijst|herstel|verwijder> [type] [naam] [tijdstip]"
    echo ""
    echo "Voorbeelden:"
    echo "  snapshot.sh maak   klant jan-bakker"
    echo "  snapshot.sh maak   lab   mqtt-project"
    echo "  snapshot.sh lijst"
    echo "  snapshot.sh herstel klant jan-bakker 2026-04-05T14:30"
    ;;

esac
