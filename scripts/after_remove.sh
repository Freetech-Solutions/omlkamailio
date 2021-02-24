#!/bin/bash
# Script that runs after kamailio remove
echo "Removing kamailio symbolic links and folders"
rm -rf /usr/sbin/kamcmd
rm -rf /usr/sbin/kamctl
rm -rf /opt/omnileads/kamailio
existe=$(grep -c '^omnileads:' /etc/passwd)
if [ $existe -eq 0 ]; then
  echo ""
else
  echo "Deleting omnileads user"
  userdel omnileads
fi
if [ -f /etc/profile.d/omnileads_envars.sh ]; then
  echo "Deleting envars"
  rm -rf /etc/profile.d/omnileads_envars.sh
fi
