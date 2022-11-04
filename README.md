# Kamailio for OMniLeads

This repository has the code of Kamailio component, configuration used for OMniLeads

## Docker image

* **Kamailio Version:** 5.3.8
* **Base Image:** kamailio/kamailio:5.3.8-buster3

### Build

```
  docker build -f Dockerfile -t freetechsolutions/omlkam:$TAG ../..
```
Where $TAG is the docker tag you want for image.

### Run container

```
docker run -it freetechsolutions/kamailio:latest bash
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
  KAMAILIO_CERTS_LOCATION // location of kamailio certs
```

**NOTE**

* If kamailio can't access redis and rtpengine services, kamailio service will not start.
* If kamailio can't access asterisk calls in OMniLeads will not be correctly made.
* If you change any network parameter in servers, you must edit again the parameters in inventory file and re-run ansible to write the files and restart the service.
---
