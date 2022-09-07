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

# *********************************** SET ENV VARS ************************************************

SRC=/usr/src
COMPONENT_REPO=https://gitlab.com/omnileads/omlkamailio.git
COMPONENT=omlkamailio

echo "******************** IPV4 address config ***************************"
echo "******************** IPV4 address config ***************************"

PUBLIC_IPV4=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
PRIVATE_IPV4=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)

apt update && apt install -y ansible

echo "************************ clone REPO *************************"
echo "************************ clone REPO *************************"
echo "************************ clone REPO *************************"
cd $SRC
git clone $COMPONENT_REPO
cd $COMPONENT
git checkout ${oml_kamailio_release}
cd deploy

echo "************************ config and install *************************"
echo "************************ config and install *************************"
echo "************************ config and install *************************"
sed -i "s/asterisk_hostname=/asterisk_hostname=${oml_acd_host}/g" ./inventory
sed -i "s/kamailio_hostname=/kamailio_hostname=$PRIVATE_IPV4/g" ./inventory
sed -i "s/kamailio_lan_ip=/kamailio_lan_ip=$PRIVATE_IPV4/g" ./inventory
sed -i "s/kamailio_wan_ip=/kamailio_wan_ip=$PUBLIC_IPV4/g" ./inventory
sed -i "s/redis_hostname=/redis_hostname=${oml_redis_host}/g" ./inventory
sed -i "s/rtpengine_hostname=/rtpengine_hostname=${oml_rtpengine_host}/g" ./inventory
sed -i "s/shm_size=/shm_size=${oml_kamailio_shm_size}/g" ./inventory
sed -i "s/pkg_size=/pkg_size=${oml_kamailio_pkg_size}/g" ./inventory

ansible-playbook kamailio.yml -i inventory --extra-vars "repo_location=$(pwd)/.. kamailio_version=$(cat ../.package_version)"
