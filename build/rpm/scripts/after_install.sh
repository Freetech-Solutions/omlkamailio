#!/bin/bash
set -e
# Script that runs after kamailio install
KAMAILIO_LOCATION="/opt/omnileads/kamailio"
if [ ! -f /usr/sbin/kamcmd ]; then
  echo "Linking kamailio binary kamcmd to /usr/sbin"
  ln -s $KAMAILIO_LOCATION/sbin/kamcmd /usr/sbin/kamcmd
fi
if [ ! -f /usr/sbin/kamctl ]; then
  echo "Linking kamailio binary kamctl to /usr/sbin"
  ln -s $KAMAILIO_LOCATION/sbin/kamctl /usr/sbin/kamctl
fi
chown -R omnileads. /opt/omnileads/kamailio
echo "Enabling kamailio"
systemctl enable kamailio
