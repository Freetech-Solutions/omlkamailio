#!/bin/sh
set -eu

is_true() {
  case "$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes|y) return 0 ;;
    *) return 1 ;;
  esac
}

SHM_SIZE="${SHM_SIZE:-128}"
PKG_SIZE="${PKG_SIZE:-16}"

HOMER_ENABLE="${HOMER_ENABLE:-}"
HOMER_HOST="${HOMER_HOST:-homer_host}"
HOMER_PORT="${HOMER_PORT:-9060}"
HOMER_CAPTURE_ID="${HOMER_CAPTURE_ID:-2003}"
HOMER_NODE_NAME="${HOMER_NODE_NAME:-}"

# hep_capture_id (modparam siptrace) must be a 32-bit integer, not a string label
case "${HOMER_CAPTURE_ID}" in
  ''|*[!0-9]*)
    echo "WARNING: HOMER_CAPTURE_ID must be numeric (got '${HOMER_CAPTURE_ID}'), using 2003"
    HOMER_CAPTURE_ID=2003
    ;;
esac

export HOMER_HOST HOMER_PORT HOMER_CAPTURE_ID HOMER_NODE_NAME

# ---------------------------------------------------------------------------
# Generate /etc/kamailio/acd_allowlist.cfg from ACD_NET_ADDR
# Comma-separated entries: ip, ip:port (port ignored), or CIDR (10.0.0.0/24).
# ---------------------------------------------------------------------------
ACD_NET_ADDR="${ACD_NET_ADDR:-}"
ACD_FILE="/etc/kamailio/acd_allowlist.cfg"

{
  echo "# Auto-generated from ACD_NET_ADDR — do not edit manually"
  echo "route[IS_FROM_ACD] {"
  if [ -z "$(echo "${ACD_NET_ADDR}" | tr -d '[:space:],')" ]; then
    echo "WARNING: ACD_NET_ADDR is empty; no ACD source IP will skip WebRTC auth" >&2
    echo "    return -1;"
  else
    IFS=','
    for entry in ${ACD_NET_ADDR}; do
      entry="$(echo "${entry}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [ -n "${entry}" ] || continue
      entry="${entry#label=}"
      case "${entry}" in
        */*)
          echo "    if (src_ip == ${entry}) return 1;"
          ;;
        *:*)
          ip="${entry%%:*}"
          echo "    if (\$si == \"${ip}\") return 1;"
          ;;
        *)
          echo "    if (\$si == \"${entry}\") return 1;"
          ;;
      esac
    done
    unset IFS
    echo "    return -1;"
  fi
  echo "}"
} > "${ACD_FILE}"

echo "Generated ${ACD_FILE}:"
cat "${ACD_FILE}"

KAMAILIO_ARGS="-DD -E -m ${SHM_SIZE} -M ${PKG_SIZE} -f /etc/kamailio/kamailio_webrtc.cfg"
if is_true "${HOMER_ENABLE}"; then
  echo "Enabling HOMER HEP capture -> ${HOMER_HOST}:${HOMER_PORT} (capture_id=${HOMER_CAPTURE_ID} node=${HOMER_NODE_NAME:-n/a})"
  KAMAILIO_ARGS="${KAMAILIO_ARGS} -A WITH_HOMER"
fi
exec kamailio ${KAMAILIO_ARGS}
