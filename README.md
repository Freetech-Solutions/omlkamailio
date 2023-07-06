# Kamailio for OMniLeads

This repository has the code of Kamailio component, configuration used for OMniLeads

## Build

To build an image:

```
docker buildx build --file=Dockerfile --tag=$TAG --target=run .
```

Where $TAG is the docker tag you want for image. You can check the version.txt file for the tag.

## Deploy

[OMniLeads Deploy Tool](https://gitlab.com/omnileads/omldeploytool)

## License

GPLV3