# Etapa 1: Compilación
FROM debian:bullseye-slim as build

ENV KAM_VERSION=5.8.3
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependencias necesarias para compilar Kamailio y sus módulos
RUN apt update && apt install -y \
    make autoconf pkg-config gcc g++ flex bison \
    libssl-dev libcurl4-openssl-dev libxml2-dev libpcre2-dev gnupg wget \
    libhiredis-dev \
    && rm -rf /var/lib/apt/lists/*

# Configurar repositorio de Kamailio
RUN echo "deb https://deb-archive.kamailio.org/repos/kamailio-${KAM_VERSION} bullseye main" > /etc/apt/sources.list.d/kamailio.list \
    && wget -O /tmp/kamailiodebkey.gpg https://deb.kamailio.org/kamailiodebkey.gpg \
    && gpg --output /etc/apt/trusted.gpg.d/deb-kamailio-org.gpg --dearmor /tmp/kamailiodebkey.gpg

# Instalar Kamailio y los módulos necesarios
RUN apt update && apt install -y \
    kamailio=${KAM_VERSION}+bpo11 \
    kamailio-autheph-modules=${KAM_VERSION}+bpo11 \
    kamailio-dbg=${KAM_VERSION}+bpo11 \
    kamailio-geoip-modules=${KAM_VERSION}+bpo11 \
    kamailio-geoip2-modules=${KAM_VERSION}+bpo11 \
    kamailio-lwsc-modules=${KAM_VERSION}+bpo11 \
    kamailio-outbound-modules=${KAM_VERSION}+bpo11 \
    kamailio-memcached-modules=${KAM_VERSION}+bpo11 \
    kamailio-nth=${KAM_VERSION}+bpo11 \
    kamailio-redis-modules=${KAM_VERSION}+bpo11 \
    kamailio-sctp-modules=${KAM_VERSION}+bpo11 \
    kamailio-tls-modules=${KAM_VERSION}+bpo11 \
    kamailio-utils-modules=${KAM_VERSION}+bpo11 \
    kamailio-websocket-modules=${KAM_VERSION}+bpo11 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Etapa 2: Imagen final
FROM debian:bullseye-slim as run

ENV SHM_SIZE=64
ENV PKG_SIZE=8

# Copiar solo los binarios, módulos y bibliotecas necesarias de Kamailio
COPY --from=build /usr/sbin/kamailio /usr/sbin/kamailio
COPY --from=build /etc/kamailio /etc/kamailio
COPY --from=build /usr/lib/x86_64-linux-gnu/kamailio/ /usr/lib/x86_64-linux-gnu/kamailio/
COPY --from=build /usr/lib/x86_64-linux-gnu/libhiredis.so.0.14 /usr/lib/x86_64-linux-gnu/libhiredis.so.0.14
COPY --from=build /usr/share/kamailio/ /usr/share/kamailio/

RUN apt update && apt install -y netbase && apt-get clean && mkdir /etc/kamailio/certs

COPY source/kamailio.cfg /etc/kamailio/
COPY source/certs/* /etc/kamailio/certs/

ENTRYPOINT ["/bin/sh", "-c", "kamailio -DD -E -m ${SHM_SIZE} -M ${PKG_SIZE} -f /etc/kamailio/kamailio.cfg"]

