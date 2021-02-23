#!/bin/bash

docker login -u $DOCKER_USER -p $DOCKER_PASSWORD

if [ $CI_COMMIT_REF_NAME == "master" ]; then
  docker build -t freetechsolutions/omlnginx:latest .
  docker push freetechsolutions/omlnginx:latest
elif [ $CI_COMMIT_REF_NAME == "develop" ]; then
  docker build -t freetechsolutions/omlnginx:develop .
  docker push freetechsolutions/omlnginx:develop
elif [[ $CI_COMMIT_REF_NAME == *"release"* ]]; then
  BRANCH=$(echo $CI_COMMIT_REF_NAME|awk -F '-' '{print $2}')
  docker build -t freetechsolutions/omlnginx:$BRANCH .
  docker push freetechsolutions/omlnginx:$BRANCH
fi
