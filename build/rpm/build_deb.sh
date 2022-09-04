#!/bin/bash

KAMAILIO_VERSION=$(cat ../../.kamailio_version)
PACKAGE_VERSION=$(cat ../../.package_version)
KAMAILIO_LOCATION="/opt/omnileads/kamailio"

if test -z ${KAMAILIO_VERSION}; then
  echo "${PROGNAME}: KAMAILIO_VERSION required" >&2
  exit 1
fi

echo "Downloading kamailio source"
mkdir -p /usr/src/kamailio
cd /usr/src/
git clone --depth 1 --no-single-branch https://github.com/kamailio/kamailio kamailio
cd kamailio
git checkout ${KAMAILIO_VERSION}

#curl -vsL https://github.com/kamailio/kamailio/archive/${KAMAILIO_VERSION}.tar.gz | tar --strip-components 1 -xz

# 1.5 jobs per core works out okay
: ${JOBS:=$(( $(nproc) + $(nproc) / 2 ))}

echo "Executing make"
# Make of modules list files
make PREFIX=${KAMAILIO_LOCATION} cfg

# Add desired modules
MODULES="auth_ephemeral db_redis outbound tls uuid websocket"
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
mkdir -p ${KAMAILIO_LOCATION}/run/kamailio ${KAMAILIO_LOCATION}/etc/certs
mkdir -p /var/log/kamailio
touch /var/log/kamailio/kamailio.log
cd /builds/omnileads/omlkamailio

echo "Adding kamailio.cfg omnileads"
cp -a source/conf/kamailio.cfg ${KAMAILIO_LOCATION}/etc/kamailio/kamailio.cfg

echo "Packing the rpm"
fpm -s dir -t deb -n kamailio -v ${PACKAGE_VERSION} \
  --deb-user omnileads \
  --deb-group omnileads \
  --before-install build/rpm/scripts/before_install.sh \
  --after-install build/rpm/scripts/after_install.sh \
  --after-remove build/rpm/scripts/after_remove.sh \
  -f ${KAMAILIO_LOCATION} \
  build/rpm/kamailio.service=/etc/systemd/system/kamailio.service

mv kamailio_${PACKAGE_VERSION}* /root
echo "Uploading RPM to AWS repository"
aws s3 cp /root/kamailio* s3://${AWS_BUCKET}/kamailio/kamailio_${PACKAGE_VERSION}_amd64.deb
