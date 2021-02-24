# Kamailio for OMniLeads

This repository has the code of Kamailio component, configuration used for OMniLeads

## Docker image

* **Kamailio Version:** 5.3
* **Base Image:** kamailio/kamailio-ci:5.3

### Build

```
  docker build -t freetechsolutions/omlkam:$TAG .
```
Where $TAG is the docker tag you want for image.

### Run container

```
  docker run -it freetechsolutions/omlkam:latest bash
```

If you need to add environment variables and link folders to container, check docker run documentation: https://docs.docker.com/engine/reference/commandline/run/

**Environment variables needed:**
```
  KAMAILIO_HOSTNAME //hostname of kamailio container
  ASTERISK_HOSTNAME //hostname of asterisk container
  REDIS_HOSTNAME // hostname of redis service
  RTPENGINE_HOSTNAME //hostname of rtpengine service
  AUTHEPH_SK //secret key for authephemeral SIP credentials
  SHM_SIZE // maximum memory ammount will consume kamailio
  PKG_SIZE // minimum memory ammount will consume kamailio
```

## RPM

### Build

* **Kamailio version:** The Kamailio base version is written in file `.kamailio_version`
* **Package version:** We provide the package with all the files configured for using Kamailio with OMniLeads. The version of the package is in `.package_version` file

Test the RPM build with these steps:

1. Check variables for container builder in `scripts/.env_buildercontainer` file.
2. Run scripts/builder_container.sh script
3. Execute build_rpm.sh script

### Deploy

To deploy Kamailio in a dedicated host two main steps are needed:

1. Install OMniLeads in its host, editing the parameter `kamailio_host` with the IP or hostname of the machine where Kamailio will be installed.
2. Install Kamailio in its host, following these steps:

**SO:** Centos7 and derivatives

* Update the machine
```
  yum update -y
```
* Set timezone in accordance where you need it
* Disable selinux if enabled
```
  sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux
  sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
```
* Disable firewalld if enabled
```
  systemctl disable firewalld
  systemctl stop firewalld
```
* Reboot the machine
* Install git
```
  yum install git -y
```
* Clone this repository where you want
```
  git clone https://gitlab.com/omnileads/omlkamailio.git
```
* Install ansible in the dedicated host.
```
  yum install python3-pip python3 epel-release -y
  pip3 install pip --upgrade
  pip3 install 'ansible==2.9.2'
```
* Go to `ansible` directory
```
  cd omlkamailio/ansible
```
* Open the file ansible/inventory and set there the parameters.
```
  [prodenv-aio:vars]
  ## IP or hostnames of services that interact with kamailio       ###
  ## WARNING: if you use hostnames you manage the hostname resolve ###
  asterisk_hostname=192.168.100.62
  kamailio_hostname=192.168.100.63
  redis_hostname=192.168.100.62
  rtpengine_hostname=192.168.100.62
  ### Kamailio Memory parameters ####
  ### SHM is the maximum memory ammount ###
  ### PKG is the minimum memory ammount ###
  shm_size=64
  pkg_size=8
```

In this example we have asterisk, redis and rtpengine installed in a host with IP 192.168.100.62 and kamailio will be installed in the host with IP 192.168.100.63.

* Run ansible-playbook   
```
  ansible-playbook kamailio.yml -i inventory --extra-vars "repo_location=$(pwd)/.. kamailio_version=$(cat ../.package_version)"
```
---
**NOTE**

* If kamailio can't access redis and rtpengine services, kamailio service will not start.
* If kamailio can't access asterisk calls in OMniLeads will not be correctly made.
* If you change any network parameter in servers, you must edit again the parameters in inventory file and re-run ansible to write the files and restart the service.
---
