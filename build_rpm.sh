#!/bin/bash

KAMAILIO_VERSION=$(cat .kamailio_version)
PACKAGE_VERSION=$(cat .package_version)

if test -z ${KAMAILIO_VERSION}; then
  echo "${PROGNAME}: KAMAILIO_VERSION required" >&2
  exit 1
fi

echo "Downloading kamailio source"
mkdir -p /usr/src/kamailio
cd /usr/src/kamailio

curl -vsL https://github.com/kamailio/kamailio/archive/${KAMAILIO_VERSION}.tar.gz | tar --strip-components 1 -xz

# 1.5 jobs per core works out okay
: ${JOBS:=$(( $(nproc) + $(nproc) / 2 ))}

echo "Executing make"
# Make of modules list files
make PREFIX=/opt/omnileads/kamailio cfg

# Add desired modules
MODULES="presence presence_xml app_python auth_ephemeral db_redis outbound tls uuid websocket"
echo "include_modules= $MODULES" >> src/modules.lst

until make -j ${JOBS} all
do
  >&2 echo "Make of kamailio failed, retrying"
done
  sleep 1
  >&2 echo "Make of kamailio done"
echo "Executing make install"
make install
rm -rf /usr/src/kamailio

echo "Creating additional folders"
mkdir -p /opt/omnileads/kamailio/run/kamailio /opt/omnileads/kamailio/etc/certs
mkdir -p /var/log/kamailio
touch /var/log/kamailio/kamailio.log

echo "Adding kamailio.cfg omnileads"
cp -a /builds/omnileads/omlkamailio/conf/kamailio.cfg /opt/omnileads/kamailio/etc/kamailio/kamailio.cfg

echo "Packing the rpm"
cd /root/
fpm -s dir -d hiredis -d hiredis-devel -t rpm -n kamailio -v ${PACKAGE_VERSION} \
  --rpm-user omnileads \
  --rpm-group omnileads \
  -f /opt/omnileads/kamailio \
  /builds/omnileads/omlkamailio/kamailio.service=/etc/systemd/system/kamailio.service

echo "Uploading RPM to AWS repository"
aws s3 cp kamailio* s3://${AWS_BUCKET}/kamailio/kamailio-${PACKAGE_VERSION}.x86_64.rpm
