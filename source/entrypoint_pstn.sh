#!/bin/sh
set -eu

is_true() {
  case "$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes|y) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
SHM_SIZE="${SHM_SIZE:-64}"
PKG_SIZE="${PKG_SIZE:-8}"
ASTERISK_SETID="${ASTERISK_SETID:-10}"
ASTERISK_PORT="${ASTERISK_PORT:-5070}"
KAMAILIO_UDP_PORT="${KAMAILIO_UDP_PORT:-5060}"

HOMER_ENABLE="${HOMER_ENABLE:-}"
HOMER_HOST="${HOMER_HOST:-homer_host}"
HOMER_PORT="${HOMER_PORT:-9060}"
HOMER_CAPTURE_ID="${HOMER_CAPTURE_ID:-2002}"
HOMER_NODE_NAME="${HOMER_NODE_NAME:-}"

KAMAILIO_CERTS_LOCATION="${KAMAILIO_CERTS_LOCATION:-/etc/kamailio/certs}"
KAMAILIO_TLS_ENABLE="${KAMAILIO_TLS_ENABLE:-}"

# hep_capture_id (modparam siptrace) must be a 32-bit integer
case "${HOMER_CAPTURE_ID}" in
  ''|*[!0-9]*)
    echo "WARNING: HOMER_CAPTURE_ID must be numeric (got '${HOMER_CAPTURE_ID}'), using 2002"
    HOMER_CAPTURE_ID=2002
    ;;
esac

export HOMER_HOST HOMER_PORT HOMER_CAPTURE_ID HOMER_NODE_NAME
export KAMAILIO_CERTS_LOCATION

# ---------------------------------------------------------------------------
# Validate required environment
# ---------------------------------------------------------------------------
for var in IPADDR_PUBLIC IPADDR_PRIVATE FQDN RTPENGINE_SOCKET ACD_NODES ITSP_NODES; do
  eval "val=\${${var}:-}"
  if [ -z "${val}" ]; then
    echo "ERROR: environment variable '${var}' must be set" >&2
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# Parse a single ACD node entry -> sip:host:port
# Supports: host, host:port, sip:host:port, label=host:port
# ---------------------------------------------------------------------------
parse_acd_node() {
  local raw="$1"
  local node="${raw#label=}"
  node="$(echo "${node}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -n "${node}" ] || return 1

  case "${node}" in
    sip:*)
      echo "${node}"
      ;;
    *:*)
      echo "sip:${node}"
      ;;
    *)
      echo "sip:${node}:${ASTERISK_PORT}"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Generate /etc/kamailio/dispatcher.list from ACD_NODES
# ---------------------------------------------------------------------------
DISPATCHER_FILE="/etc/kamailio/dispatcher.list"
SOCKET_ATTR="socket=udp:${IPADDR_PRIVATE}:${KAMAILIO_UDP_PORT}"

: > "${DISPATCHER_FILE}"
priority=0
IFS=','

for entry in ${ACD_NODES}; do
  entry="$(echo "${entry}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -n "${entry}" ] || continue

  dest="$(parse_acd_node "${entry}")" || continue
  priority=$((priority + 1))
  echo "${ASTERISK_SETID} ${dest} 2 ${priority} ${SOCKET_ATTR}" >> "${DISPATCHER_FILE}"
done

unset IFS

if [ ! -s "${DISPATCHER_FILE}" ]; then
  echo "ERROR: ACD_NODES produced an empty ${DISPATCHER_FILE}" >&2
  exit 1
fi

echo "Generated ${DISPATCHER_FILE}:"
cat "${DISPATCHER_FILE}"

# ---------------------------------------------------------------------------
# Generate /etc/kamailio/itsp_allowlist.cfg from ITSP_NODES
# ---------------------------------------------------------------------------
ITSP_FILE="/etc/kamailio/itsp_allowlist.cfg"

{
  echo "# Auto-generated from ITSP_NODES — do not edit manually"
  echo "route[IS_FROM_ITSP] {"
  if [ -z "$(echo "${ITSP_NODES}" | tr -d '[:space:],')" ]; then
    echo "    return -1;"
  else
  IFS=','
  for entry in ${ITSP_NODES}; do
    entry="$(echo "${entry}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "${entry}" ] || continue
    ip="${entry#label=}"
    ip="${ip%%:*}"
    ip="$(echo "${ip}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "${ip}" ] || continue
    echo "    if (\$si == \"${ip}\") return 1;"
  done
  unset IFS
  echo "    return -1;"
  fi
  echo "}"
} > "${ITSP_FILE}"

echo "Generated ${ITSP_FILE}"

# ---------------------------------------------------------------------------
# Start Kamailio
# ---------------------------------------------------------------------------
KAMAILIO_ARGS="-DD -E -m ${SHM_SIZE} -M ${PKG_SIZE} -f /etc/kamailio/kamailio_pstn.cfg"

if is_true "${HOMER_ENABLE}"; then
  echo "Enabling HOMER HEP capture -> ${HOMER_HOST}:${HOMER_PORT} (capture_id=${HOMER_CAPTURE_ID} node=${HOMER_NODE_NAME:-n/a})"
  KAMAILIO_ARGS="${KAMAILIO_ARGS} -A WITH_HOMER"
fi

if is_true "${KAMAILIO_TLS_ENABLE}"; then
  if [ -f "${KAMAILIO_CERTS_LOCATION}/cert.pem" ] && [ -f "${KAMAILIO_CERTS_LOCATION}/key.pem" ]; then
    echo "Enabling TLS (certs in ${KAMAILIO_CERTS_LOCATION})"
    KAMAILIO_ARGS="${KAMAILIO_ARGS} -A WITH_TLS"
  else
    echo "WARNING: KAMAILIO_TLS_ENABLE set but certs missing in ${KAMAILIO_CERTS_LOCATION}" >&2
  fi
fi

exec kamailio ${KAMAILIO_ARGS} "$@"