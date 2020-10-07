#!/bin/bash

docker login -u $FTS_DOCKER_USER -p $FTS_DOCKER_PASSWORD

if [ $CI_COMMIT_REF_NAME == "master" ]; then
  docker build -t freetechsolutions/omlkam:latest .
  docker push freetechsolutions/omlkam:latest
else
  docker build -t freetechsolutions/omlkam:$CI_COMMIT_SHORT_SHA .
  docker build -t freetechsolutions/omlkam:develop .
  docker push freetechsolutions/omlkam:$CI_COMMIT_SHORT_SHA
  docker push freetechsolutions/omlkam:develop
fi
