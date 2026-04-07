#!/usr/bin/env bash
# ulid.sh — genereert een ULID (Universally Unique Lexicographically Sortable ID)
# Output: ULID als string

# ─── CuiperModuleLib ─────────────────────────────────────────────────────────
_CUIPER_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/protocol/CuiperModuleLib.sh
source "${_CUIPER_LIB_DIR}/CuiperModuleLib.sh" 2>/dev/null || true
CUIPER_MODULE_NAAM="CuiperUlid"
CUIPER_MODULE_VERSIE="0.2.0"
CUIPER_IN="none"
CUIPER_OUT="stdout"
CUIPER_MODULE_OMSCHRIJVING="Genereert een ULID (Universally Unique Lexicographically Sortable ID)"
CUIPER_MODULE_WERKING="Timestamp-deel 10 chars + random-deel 16 chars. Output naar stdout."
cuiper_init_flags "$@"
# ─────────────────────────────────────────────────────────────────────────────

# Alle output naar stdout, niets naar /dev/null

ENCODING="0123456789ABCDEFGHJKMNPQRSTVWXYZ"

ts_ms=$(date +%s%3N)

# Timestamp deel (10 chars)
ulid_ts=""
n=$ts_ms
for i in $(seq 1 10); do
  ulid_ts="${ENCODING:$((n % 32)):1}${ulid_ts}"
  n=$((n / 32))
done

# Random deel (16 chars)
ulid_rand=""
for i in $(seq 1 16); do
  ulid_rand="${ulid_rand}${ENCODING:$((RANDOM % 32)):1}"
done

ULID="${ulid_ts}${ulid_rand}"
echo "$ULID"
