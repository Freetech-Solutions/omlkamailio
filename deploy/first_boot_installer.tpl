#!/bin/bash

########################## README ############ README ############# README #########################
########################## README ############ README ############# README #########################
# El script first_boot_installer tiene como finalidad desplegar el componente sobre una instancia
# de linux exclusiva. Las variables que utiliza son "variables de entorno" de la instancia que está
# por lanzar el script como acto seguido al primer boot del sistema operativo.
# Dichas variables podrán ser provisionadas por un archivo .env (ej: Vagrant) o bien utilizando este
# script como plantilla de terraform.
#
# En el caso de necesitar ejecutar este script manualmente sobre el user_data de una instancia cloud
# o bien sobre una instancia onpremise a través de una conexión ssh, entonces se deberá copiar
# esta plantilla hacia un archivo ignorado por git: first_boot_installer.sh para luego sobre
# dicha copia descomentar las líneas que comienzan con la cadena "export" para posteriormente
# introducir el valor deseado a cada variable.
########################## README ############ README ############# README #########################
########################## README ############ README ############# README #########################

# *********************************** SET ENV VARS **************************************************
# *********************************** SET ENV VARS **************************************************

# The infrastructure environment:
# onpremise | digitalocean | linode | vultr | aws
#export oml_infras_stage=onpremise

# Set your net interfaces, you must have at least a PRIVATE_NIC
#export oml_nic=eth1

# Component gitlab branch
#export oml_kamailio_release=210629.01

#export oml_redis_host=
#export oml_acd_host=
#export oml_rtpengine_host=

#export oml_kamailio_shm_size=64
#export oml_kamailio_pkg_size=8
# *********************************** SET ENV VARS **************************************************
# *********************************** SET ENV VARS **************************************************

SRC=/usr/src
COMPONENT_REPO=https://gitlab.com/omnileads/omlkamailio.git

echo "******************** IPV4 address config ***************************"
echo "******************** IPV4 address config ***************************"
case ${oml_infras_stage} in
  aws)
    echo -n "AWS"
    PRIVATE_IPV4=${oml_kamailio_host}
    ;;
  digitalocean)
    echo -n "DigitalOcean"
    PRIVATE_IPV4=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)
    ;;
  linode)
    echo -n "Linode"
    PRIVATE_IPV4=$(ip addr show ${oml_nic} |grep "inet 192.168" |awk '{print $2}' | cut -d/ -f1)
    ;;
  onpremise)
    echo -n "Onpremise CentOS7 Minimal"
    PRIVATE_IPV4=$(ip addr show ${oml_nic} | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
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

case ${oml_infras_stage} in
  aws)
    yum remove -y python3 python3-pip
    yum install -y $SSM_AGENT_URL 
    yum install -y patch libedit-devel libuuid-devel git
    amazon-linux-extras install epel
    amazon-linux-extras install python3
    systemctl start amazon-ssm-agent
    yum install -y patch libedit-devel libuuid-devel git
    yum install -y https://centos.pkgs.org/7/okey-x86_64/hiredis-0.12.1-1.el7.centos.x86_64.rpm.html
    yum install -y http://www6.atomicorp.com/channels/atomic/centos/7/x86_64/RPMS/hiredis-devel-0.12.1-1.el7.art.x86_64.rpm
    systemctl start amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    ;;
  *)
    #yum update -y
    yum -y install epel-release git python3 python3-pip libselinux-python3
    ;;
esac

echo "************************ install ansible *************************"
echo "************************ install ansible *************************"
echo "************************ install ansible *************************"
pip3 install pip --upgrade
pip3 install boto boto3 botocore 'ansible==2.9.9'
export PATH="$HOME/.local/bin/:$PATH"

echo "************************ clone REPO *************************"
echo "************************ clone REPO *************************"
echo "************************ clone REPO *************************"
cd $SRC
git clone $COMPONENT_REPO
cd omlkamailio
git checkout ${oml_kamailio_release}
cd deploy

echo "************************ config and install *************************"
echo "************************ config and install *************************"
echo "************************ config and install *************************"
sed -i "s/asterisk_hostname=/asterisk_hostname=${oml_acd_host}/g" ./inventory
sed -i "s/kamailio_hostname=/kamailio_hostname=$PRIVATE_IPV4/g" ./inventory
sed -i "s/redis_hostname=/redis_hostname=${oml_redis_host}/g" ./inventory
sed -i "s/rtpengine_hostname=/rtpengine_hostname=${oml_rtpengine_host}/g" ./inventory
sed -i "s/shm_size=/shm_size=${oml_kamailio_shm_size}/g" ./inventory
sed -i "s/pkg_size=/pkg_size=${oml_kamailio_pkg_size}/g" ./inventory

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
