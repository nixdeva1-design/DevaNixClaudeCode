#!/usr/bin/env bash
# CuiperIdee.sh — Verkorte notitie voor ideeën via ci:: prefix
# Erft van: CuiperCore → CuiperDonut → CuiperClaudeCodeTakenlijst → CuiperIdeeOperator
#
# Gebruik:
#   bash CuiperIdee.sh "tekst van het idee"
#   bash CuiperIdee.sh "tekst" --local-time "2026-04-07T23:00:00+02:00"
#
# Gedrag:
#   1. Genereert ULID voor het idee
#   2. Voegt toe aan CuiperBacklog.md met status WEES, prioriteit CuiperIdee
#   3. Voegt toe aan logs/wezen/CuiperWezen.jsonl
#   4. Bij conflict: voegt toe aan logs/wezen/CuiperConflicten.jsonl
#   5. Commit + push
#   6. Print ULID — caller gaat daarna door met vorige taak
#
# Wet: dit script ontwerpt NIETS. Het registreert alleen. Geen verdere actie.

set -euo pipefail

# ─── CuiperModuleLib ─────────────────────────────────────────────────────────
_CUIPER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/protocol/CuiperModuleLib.sh
source "${_CUIPER_LIB_DIR}/CuiperModuleLib.sh" 2>/dev/null || true
CUIPER_MODULE_NAAM="CuiperIdee"
CUIPER_MODULE_VERSIE="0.2.0"
CUIPER_IN="args"
CUIPER_OUT="file"
CUIPER_MODULE_OMSCHRIJVING="Registreer ci:: ideeen als WEES in CuiperBacklog en CuiperWezen.jsonl"
CUIPER_MODULE_WERKING="Extraheert tekst na ci:: prefix. Conflicten gesedimenteerd in CuiperConflicten.jsonl."
cuiper_init_flags "$@"
# ─────────────────────────────────────────────────────────────────────────────


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../CuiperConfig.env" 2>/dev/null || {
    CUIPER_REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
    CUIPER_TRAIL_DIR="$CUIPER_REPO/logs/trail"
    CUIPER_BACKLOG_DIR="$CUIPER_REPO/backlog"
}

WEZEN_DIR="$CUIPER_REPO/logs/wezen"
WEZEN_FILE="$WEZEN_DIR/CuiperWezen.jsonl"
CONFLICTEN_FILE="$WEZEN_DIR/CuiperConflicten.jsonl"
BACKLOG_FILE="$CUIPER_BACKLOG_DIR/CuiperBacklog.md"

mkdir -p "$WEZEN_DIR"

log_fout() {
    echo "[FOUT] $*" >&2
    echo "[FOUT] $(date +%s) $*" >> "$CUIPER_TRAIL_DIR/$(date +%s)-idee-fout-CUIPER.log"
}

# ─── Args ─────────────────────────────────────────────────────────────────────
TEKST=""
LOCAL_TIME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --local-time) LOCAL_TIME="$2"; shift 2 ;;
        *)            TEKST="${TEKST:+$TEKST }$1"; shift ;;
    esac
done

if [[ -z "$TEKST" ]]; then
    log_fout "CuiperIdee.sh: geen tekst opgegeven"
    echo "Gebruik: bash CuiperIdee.sh \"tekst van het idee\"" >&2
    exit 1
fi

# ─── ULID genereren ───────────────────────────────────────────────────────────
# Eenvoudige ULID: timestamp (10 hex) + random (22 hex)
UNIX_MS=$(date +%s%3N)
UNIX_S=$(date +%s)
RAND_HEX=$(cat /dev/urandom | tr -dc 'A-Z0-9' | head -c 22 2>/dev/null || \
           awk 'BEGIN{srand(); s=""; for(i=0;i<22;i++) s=s substr("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",int(rand()*36)+1,1); print s}')
ULID_WEZEN="01CI${RAND_HEX}"
ULID_BACKLOG="${ULID_WEZEN}"  # zelfde ULID voor backlog + wezen → de join

# ─── Conflict check: bestaat dit idee al? ─────────────────────────────────────
if [[ -f "$WEZEN_FILE" ]]; then
    BESTAAND=$(grep -F "\"tekst\":\"${TEKST}\"" "$WEZEN_FILE" 2>/dev/null || true)
    if [[ -n "$BESTAAND" ]]; then
        CONFLICT_ULID="01CI${RAND_HEX}CONF"
        BESTAAND_ULID=$(echo "$BESTAAND" | python3 -c "import json,sys; d=json.loads(sys.stdin.read()); print(d.get('ulid','onbekend'))" 2>/dev/null || echo "onbekend")
        echo "{\"ulid\":\"$CONFLICT_ULID\",\"wezen_ulid\":\"$ULID_WEZEN\",\"bestaand_ulid\":\"$BESTAAND_ULID\",\"tekst\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$TEKST"),\"unix_ms\":$UNIX_MS,\"beschrijving\":\"Dubbel idee gedetecteerd\"}" \
            >> "$CONFLICTEN_FILE"
        echo "[CONFLICT] Idee bestaat al als $BESTAAND_ULID — geregistreerd in CuiperConflicten" >&2
    fi
fi

# ─── CuiperWezen.jsonl ────────────────────────────────────────────────────────
LOCAL_TIME_WAARDE="${LOCAL_TIME:-$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)}"

python3 - <<PYEOF >> "$WEZEN_FILE"
import json
record = {
    "ulid":           "$ULID_WEZEN",
    "backlog_ulid":   "$ULID_BACKLOG",
    "tekst":          "$TEKST",
    "unix_ms_server": $UNIX_MS,
    "local_time":     "$LOCAL_TIME_WAARDE",
    "status":         "WEES",
    "aangemaakt":     $UNIX_S
}
print(json.dumps(record, ensure_ascii=False))
PYEOF

# ─── CuiperBacklog.md ─────────────────────────────────────────────────────────
# Voeg toe boven de scheidslijn van KLAAR items
STAP_NR=$(git -C "$CUIPER_REPO" log --oneline | wc -l 2>/dev/null || echo "0")
NIEUW_ITEM="| $ULID_WEZEN | WEES | CuiperIdee | $TEKST | $STAP_NR | $ULID_BACKLOG |"

# Voeg toe na de laatste OPEN/WEES rij, vóór KLAAR sectie
if grep -q "| WEES |" "$BACKLOG_FILE" 2>/dev/null; then
    # Voeg na laatste WEES rij toe
    python3 - "$BACKLOG_FILE" "$NIEUW_ITEM" <<'PYEOF'
import sys
pad, nieuw = sys.argv[1], sys.argv[2]
with open(pad) as f:
    regels = f.readlines()
laatste_wees = -1
for i, r in enumerate(regels):
    if "| WEES |" in r:
        laatste_wees = i
if laatste_wees >= 0:
    regels.insert(laatste_wees + 1, nieuw + "\n")
else:
    # Na laatste OPEN rij
    for i, r in enumerate(regels):
        if "| OPEN |" in r:
            laatste_wees = i
    regels.insert(laatste_wees + 1, nieuw + "\n")
with open(pad, "w") as f:
    f.writelines(regels)
PYEOF
else
    # Voeg toe na laatste OPEN rij
    python3 - "$BACKLOG_FILE" "$NIEUW_ITEM" <<'PYEOF'
import sys
pad, nieuw = sys.argv[1], sys.argv[2]
with open(pad) as f:
    regels = f.readlines()
laatste_open = -1
for i, r in enumerate(regels):
    if "| OPEN |" in r:
        laatste_open = i
if laatste_open >= 0:
    regels.insert(laatste_open + 1, nieuw + "\n")
with open(pad, "w") as f:
    f.writelines(regels)
PYEOF
fi

# ─── Commit + push ────────────────────────────────────────────────────────────
cd "$CUIPER_REPO"
git add "$WEZEN_FILE" "$BACKLOG_FILE"
[[ -f "$CONFLICTEN_FILE" ]] && git add "$CONFLICTEN_FILE"

git commit -m "CuiperIdee: $ULID_WEZEN — ${TEKST:0:60}

Status: WEES | Prioriteit: CuiperIdee
Geen verdere actie. Wezen wacht op adoptie.

https://claude.ai/code/session_01LwAQ3fvpdvRMMTi8o92pKu" 2>/dev/null || true

# Push met retry
for wacht in 2 4 8 16 einde; do
    if [[ "$wacht" == "einde" ]]; then
        log_fout "Push mislukt na 4 pogingen voor idee $ULID_WEZEN"
        break
    fi
    if git push -u origin "$(git branch --show-current)" 2>/dev/null; then
        break
    fi
    sleep "$wacht"
done

# ─── Output: alleen de ULID ──────────────────────────────────────────────────
echo "$ULID_WEZEN"
