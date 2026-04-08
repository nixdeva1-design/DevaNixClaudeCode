#!/usr/bin/env bash

# ─── CuiperHeader ───────────────────────────────────────────────────────────
# ULID:          01COMP017JAEGERSPAN000000
# Naam:          scripts/protocol/CuiperJaegerSpan.sh
# Erft via:      CuiperCore → CuiperDonut
# Aangemaakt:    CuiperStapNr 35
# Gewijzigd:     CuiperStapNr 54 — 2026-04-08
# ────────────────────────────────────────────────────────────────────────────

# CuiperJaegerSpan.sh — stuur één OTLP HTTP span naar Jaeger
#
# Gebruik:
#   bash CuiperJaegerSpan.sh \
#       --trace  <32 hex>  \
#       --span   <16 hex>  \
#       --naam   <string>  \
#       --start  <unix sec>\
#       --eind   <unix sec>\
#       --status <1=OK|2=ERR> \
#       --stap   <nr>      \
#       --exit   <code>
#
# /dev/null verbod: verbindingsfouten naar trail, nooit stil

set -uo pipefail

_SPAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_SPAN_DIR/../../CuiperConfig.env"

log_fout() {
    printf "%s FOUT [CuiperJaegerSpan/%s]: %s\n" \
        "$(date +%s)" "$1" "$2" \
        >> "$CUIPER_TRAIL_DIR/$(date +%s)-jaeger-span-fout-CUIPER.log"
}

TRACE_ID="" SPAN_ID="" NAAM="onbekend"
START_S=0 EIND_S=0 STATUS_CODE=1 STAP_NR=0 EXIT_CODE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --trace)  TRACE_ID="$2";    shift 2 ;;
        --span)   SPAN_ID="$2";     shift 2 ;;
        --naam)   NAAM="$2";        shift 2 ;;
        --start)  START_S="$2";     shift 2 ;;
        --eind)   EIND_S="$2";      shift 2 ;;
        --status) STATUS_CODE="$2"; shift 2 ;;
        --stap)   STAP_NR="$2";     shift 2 ;;
        --exit)   EXIT_CODE="$2";   shift 2 ;;
        *) shift ;;
    esac
done

START_NS="${START_S}000000000"
EIND_NS="${EIND_S}000000000"
JAEGER_URL="${CUIPER_JAEGER_OTLP_URL:-http://127.0.0.1:4318}/v1/traces"

PAYLOAD=$(cat <<EOF
{
  "resourceSpans": [{
    "resource": {"attributes": [
      {"key": "service.name",    "value": {"stringValue": "cuiper-hive"}},
      {"key": "cuiper.namespace","value": {"stringValue": "${CUIPER_NAMESPACE}"}},
      {"key": "cuiper.client",   "value": {"stringValue": "${CUIPER_CLIENT_ID}"}}
    ]},
    "scopeSpans": [{"scope": {"name": "CuiperHive"}, "spans": [{
      "traceId":          "${TRACE_ID}",
      "spanId":           "${SPAN_ID}",
      "name":             "${NAAM}",
      "kind":             2,
      "startTimeUnixNano":"${START_NS}",
      "endTimeUnixNano":  "${EIND_NS}",
      "attributes": [
        {"key": "cuiper.stap_nr",   "value": {"intValue": ${STAP_NR}}},
        {"key": "cuiper.exit_code", "value": {"intValue": ${EXIT_CODE}}},
        {"key": "cuiper.branch",    "value": {"stringValue": "${CUIPER_BRANCH}"}}
      ],
      "status": {"code": ${STATUS_CODE}}
    }]}]
  }]
}
EOF
)

CURL_ERR=""
if ! CURL_ERR=$(curl -s --max-time 3 -X POST "$JAEGER_URL" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>&1); then
    log_fout "CURL" "$CURL_ERR"
fi
