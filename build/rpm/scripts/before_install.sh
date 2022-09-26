#!/bin/bash
# Script that runs before install of kamailio
echo "Checking if omnileads user/group exists"
existe=$(grep -c '^omnileads:' /etc/passwd)
if [ $existe -eq 0 ]; then
  echo " ERROR the user omnileads not exist"
  echo " ERROR the user omnileads not exist"
  echo " ERROR the user omnileads not exist"
  exit 1
else
  echo "The user/group omnileads already exists"
fi
