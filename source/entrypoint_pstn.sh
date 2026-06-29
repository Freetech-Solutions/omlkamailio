#!/bin/sh
set -eu

is_true() {
  case "$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    true|1|yes|y) return 0 ;;
    *) return 1 ;;
  esac
}

DISPATCHER_FILE="/etc/kamailio/dispatcher.list"
ITSP_FILE="/etc/kamailio/itsp_allowlist.cfg"

ASTERISK_SETID="${ASTERISK_SETID:-10}"
ASTERISK_PORT="${ASTERISK_PORT:-5060}"
ASTERISK_NODES="${ACD_NODES:-127.0.0.1:5060}"
ITSP_NODES="${ITSP_NODES:-}"
SHM_SIZE="${SHM_SIZE:-64}"
PKG_SIZE="${PKG_SIZE:-8}"

# Capturamos la IP privada del entorno (necesaria para forzar el socket)
IPADDR_PRIVATE="${IPADDR_PRIVATE:-}"

HOMER_ENABLE="${HOMER_ENABLE:-}"
HOMER_HOST="${HOMER_HOST:-homer_host}"
HOMER_PORT="${HOMER_PORT:-9060}"
HOMER_CAPTURE_ID="${HOMER_CAPTURE_ID:-2002}"
HOMER_NODE_NAME="${HOMER_NODE_NAME:-}"

# hep_capture_id (modparam siptrace) must be a 32-bit integer, not a string label
case "${HOMER_CAPTURE_ID}" in
  ''|*[!0-9]*)
    echo "WARNING: HOMER_CAPTURE_ID must be numeric (got '${HOMER_CAPTURE_ID}'), using 2002"
    HOMER_CAPTURE_ID=2002
    ;;
esac

export HOMER_HOST HOMER_PORT HOMER_CAPTURE_ID HOMER_NODE_NAME

: > "$DISPATCHER_FILE"

OLD_IFS="$IFS"
IFS=','
for node in $ASTERISK_NODES; do
    [ -n "$node" ] || continue
    node="$(echo "$node" | xargs)"

    case "$node" in
        *=*)
            host="${node#*=}"
            ;;
        *)
            host="$node"
            ;;
    esac

    case "$host" in
        sip:*)
            uri="$host"
            ;;
        *';transport='*)
            uri="sip:${host}"
            ;;
        *:*)
            uri="sip:${host}"
            ;;
        *)
            uri="sip:${host}:${ASTERISK_PORT}"
            ;;
    esac

    # MODIFICACIÓN CRÍTICA: Inyectamos el socket origen si tenemos IPADDR_PRIVATE
    if [ -n "$IPADDR_PRIVATE" ]; then
        echo "${ASTERISK_SETID} ${uri} 0 0 socket=udp:${IPADDR_PRIVATE}:5060" >> "$DISPATCHER_FILE"
    else
        echo "${ASTERISK_SETID} ${uri}" >> "$DISPATCHER_FILE"
        echo "WARNING: IPADDR_PRIVATE no definida. Kamailio usará la tabla de ruteo del SO."
    fi
done
IFS="$OLD_IFS"

echo "Generated ${DISPATCHER_FILE}:"
cat "$DISPATCHER_FILE"

: > "$ITSP_FILE"

echo 'route[IS_FROM_ITSP] {' >> "$ITSP_FILE"

if [ -z "$ITSP_NODES" ]; then
    echo "WARNING: ITSP_NODES is empty. All inbound ITSP matches will fail."
fi

OLD_IFS="$IFS"
IFS=','
for node in $ITSP_NODES; do
    [ -n "$node" ] || continue
    node="$(echo "$node" | xargs)"

    case "$node" in
        *=*)
            ip="${node#*=}"
            ;;
        *)
            ip="$node"
            ;;
    esac

    # $si es solo IP; quitar prefijo sip: y puerto si ITSP_NODES trae host:port
    ip="${ip#sip:}"
    case "$ip" in
        *:*) ip="${ip%%:*}" ;;
    esac

    echo "    if (\$si == \"$ip\") return 1;" >> "$ITSP_FILE"
done
IFS="$OLD_IFS"

echo '    return -1;' >> "$ITSP_FILE"
echo '}' >> "$ITSP_FILE"

echo "Generated ${ITSP_FILE}:"
cat "$ITSP_FILE"

KAMAILIO_ARGS="-DD -E -m ${SHM_SIZE} -M ${PKG_SIZE} -f /etc/kamailio/kamailio_pstn.cfg"
if is_true "${HOMER_ENABLE}"; then
  echo "Enabling HOMER HEP capture -> ${HOMER_HOST}:${HOMER_PORT} (capture_id=${HOMER_CAPTURE_ID} node=${HOMER_NODE_NAME:-n/a})"
  KAMAILIO_ARGS="${KAMAILIO_ARGS} -A WITH_HOMER"
fi
exec kamailio ${KAMAILIO_ARGS}
