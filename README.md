# Kamailio for OMniLeads

This repository has the code of kamailio.cfg file, configuration used for OMniLeads

Kamailio Version: 5.3
Base Image: kamailio/kamailio-ci:5.3

## Build

```
  docker build -t freetechsolutions/omlkam:$TAG .
```

## Run container

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
```
