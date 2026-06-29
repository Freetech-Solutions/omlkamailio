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

KAMAILIO_ARGS="-DD -E -m ${SHM_SIZE} -M ${PKG_SIZE} -f /etc/kamailio/kamailio_webrtc.cfg"
if is_true "${HOMER_ENABLE}"; then
  echo "Enabling HOMER HEP capture -> ${HOMER_HOST}:${HOMER_PORT} (capture_id=${HOMER_CAPTURE_ID} node=${HOMER_NODE_NAME:-n/a})"
  KAMAILIO_ARGS="${KAMAILIO_ARGS} -A WITH_HOMER"
fi
exec kamailio ${KAMAILIO_ARGS}
