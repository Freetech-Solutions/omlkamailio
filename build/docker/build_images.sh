#!/bin/bash
PACKAGE_VERSION=$(cat ../../.package_version)

docker login -u $DOCKER_USER -p $DOCKER_PASSWORD

if [ $CI_COMMIT_REF_NAME == "master" ]; then
  docker build -f Dockerfile -t freetechsolutions/omlkam:latest ../..
  docker push freetechsolutions/omlkam:latest
elif [ $CI_COMMIT_REF_NAME == "develop" ]; then
  docker build -f Dockerfile -t freetechsolutions/omlkam:develop ../..
  docker push freetechsolutions/omlkam:develop
fi

docker build -f Dockerfile -t freetechsolutions/omlkam:$PACKAGE_VERSION ../..
docker push freetechsolutions/omlkam:$PACKAGE_VERSION
