#!/bin/bash

SRC=/usr/src
COMPONENT_REPO=https://gitlab.com/omnileads/omlkamailio.git
COMPONENT_RELEASE=${omlkam_version}

STAGE=YOUR_STAGE
#STAGE=digitalocean
#STAGE=onpremise
#STAGE=linode
#STAGE=vultr

NIC=${NIC}

REDIS_HOST=${redis_host}
REDIS_PORT=6379
ASTERISK_HOST=${asterisk_host}
RTPENGINE_HOST=${rtpengine_host}
KAMAILIO_SHM_SIZE=64
KAMAILIO_PKG_SIZE=8

echo "******************** IPV4 address config ***************************"
echo "******************** IPV4 address config ***************************"
case $STAGE in
  digitalocean)
    echo -n "DigitalOcean"
    PRIVATE_IPV4=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
    ;;
  linode)
    echo -n "Linode"
    PRIVATE_IPV4=$(ip addr show $NIC |grep "inet 192.168" |awk '{print $2}' | cut -d/ -f1)
    ;;
  onpremise)
    echo -n "Onpremise CentOS7 Minimal"
    PRIVATE_IPV4=$(ip addr show $NIC | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
    ;;
  *)
    echo -n "you must to declare STAGE variable"
    ;;
esac

echo "************************ disable SElinux *************************"
echo "************************ disable SElinux *************************"
echo "************************ disable SElinux *************************"
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
setenforce 0
systemctl disable firewalld > /dev/null 2>&1
systemctl stop firewalld > /dev/null 2>&1

echo "************************ yum install  *************************"
echo "************************ yum install  *************************"
yum install -y python3 python3-pip epel-release git

echo "************************ install ansible *************************"
echo "************************ install ansible *************************"
echo "************************ install ansible *************************"
pip3 install pip --upgrade
pip3 install 'ansible==2.9.2'
export PATH="$HOME/.local/bin/:$PATH"

echo "************************ clone REPO *************************"
echo "************************ clone REPO *************************"
echo "************************ clone REPO *************************"
cd $SRC
git clone $COMPONENT_REPO
cd omlkamailio
git checkout $COMPONENT_RELEASE
cd deploy

echo "************************ config and install *************************"
echo "************************ config and install *************************"
echo "************************ config and install *************************"
sed -i "s/asterisk_hostname=/asterisk_hostname=$ASTERISK_HOST/g" ./inventory
sed -i "s/kamailio_hostname=/kamailio_hostname=$PRIVATE_IPV4/g" ./inventory
sed -i "s/redis_hostname=/redis_hostname=$REDIS_HOST/g" ./inventory
sed -i "s/rtpengine_hostname=/rtpengine_hostname=$RTPENGINE_HOST/g" ./inventory
sed -i "s/shm_size=/shm_size=$KAMAILIO_SHM_SIZE/g" ./inventory
sed -i "s/pkg_size=/pkg_size=$KAMAILIO_PKG_SIZE/g" ./inventory

ansible-playbook kamailio.yml -i inventory --extra-vars "repo_location=$(pwd)/.. kamailio_version=$(cat ../.package_version)"

echo "********************************** sngrep SIP sniffer install *********************************"
echo "********************************** sngrep SIP sniffer install *********************************"
yum install ncurses-devel make libpcap-devel pcre-devel \
openssl-devel git gcc autoconf automake -y
cd $SRC && git clone https://github.com/irontec/sngrep
cd sngrep && ./bootstrap.sh && ./configure && make && make install
ln -s /usr/local/bin/sngrep /usr/bin/sngrep

echo "************************ Remove source dirs  *************************"
echo "************************ Remove source dirs  *************************"
rm -rf $SRC/omlkamailio
