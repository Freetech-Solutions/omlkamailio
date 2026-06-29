# Etapa 1: Preparación y Descarga
FROM debian:trixie-slim AS build

ARG TARGETARCH

ENV KAM_VERSION=6.0.5
ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------
# ADVERTENCIA PARA APPLE SILICON
# ---------------------------------------------------------
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      echo "!!! ALERTA !!! ESTÁS CONSTRUYENDO EN ARQUITECTURA ARM64 (APPLE SILICON)"; \
      echo "Esta imagen funcionará en tu Mac, pero NO en servidores Intel/AMD estándar."; \
      echo "Si es para producción, usa: docker build --platform linux/amd64 ..."; \
      sleep 3; \
    fi

# Instalar dependencias base
RUN apt update && apt install -y \
    wget gnupg curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Configurar repositorio de Kamailio (Usando Bookworm)
RUN echo "deb https://deb-archive.kamailio.org/repos/kamailio-${KAM_VERSION} trixie main" > /etc/apt/sources.list.d/kamailio.list \
    && wget -O /tmp/kamailiodebkey.gpg https://deb.kamailio.org/kamailiodebkey.gpg \
    && gpg --output /etc/apt/trusted.gpg.d/deb-kamailio-org.gpg --dearmor /tmp/kamailiodebkey.gpg

# Instalar Kamailio y módulos vía APT
# NOTA: En Bookworm los paquetes ya no llevan el sufijo +bpo11 si usas el repo oficial correcto
RUN apt update && apt install -y \
    kamailio \
    kamailio-autheph-modules \
    kamailio-geoip2-modules \
    kamailio-lwsc-modules \
    kamailio-outbound-modules \
    kamailio-memcached-modules \
    kamailio-redis-modules \
    kamailio-sctp-modules \
    kamailio-tls-modules \
    kamailio-utils-modules \
    kamailio-websocket-modules \
    kamailio-outbound-modules \
    kamailio-extra-modules \
    libhiredis-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# NORMALIZACIÓN DE RUTAS
# ---------------------------------------------------------
RUN mkdir -p /kamailio-dist/modules /kamailio-dist/libs && \
    if [ "$TARGETARCH" = "amd64" ]; then LIBPATH="/usr/lib/x86_64-linux-gnu"; else LIBPATH="/usr/lib/aarch64-linux-gnu"; fi && \
    echo "Copiando desde: $LIBPATH" && \
    cp -r $LIBPATH/kamailio/* /kamailio-dist/modules/ && \
    cp $LIBPATH/libhiredis.so.1 /kamailio-dist/libs/

# Etapa 2: Imagen final
FROM debian:trixie-slim AS run

ARG TARGETARCH

# IMPORTANTE: Faltaban estas variables que usas en el ENTRYPOINT
ENV SHM_SIZE=64
ENV PKG_SIZE=8

# Instalar dependencias de runtime
# CORRECCIÓN: libhiredis -> libhiredis0.14
RUN apt update && apt install -y \
    netbase \
    libssl3 \
    libcurl4 \
    libxml2 \
    sngrep \
    libhiredis1.1.0 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/kamailio/certs

# Copiar binarios y config
COPY --from=build /usr/sbin/kamailio /usr/sbin/kamailio
COPY --from=build /etc/kamailio /etc/kamailio
COPY --from=build /usr/share/kamailio/ /usr/share/kamailio/

# Copiar módulos normalizados
RUN if [ "$TARGETARCH" = "amd64" ]; then DEST_LIB="/usr/lib/x86_64-linux-gnu"; else DEST_LIB="/usr/lib/aarch64-linux-gnu"; fi && \
    mkdir -p $DEST_LIB/kamailio && \
    mkdir -p /etc/kamailio/certs

COPY --from=build /kamailio-dist/modules/ /tmp/kamailio-modules/

RUN if [ "$TARGETARCH" = "amd64" ]; then DEST_LIB="/usr/lib/x86_64-linux-gnu"; else DEST_LIB="/usr/lib/aarch64-linux-gnu"; fi && \
    mv /tmp/kamailio-modules/* $DEST_LIB/kamailio/ && \
    rm -rf /tmp/kamailio-modules

# Configs locales
COPY source/kamailio_webrtc.cfg /etc/kamailio/
COPY source/kamailio_pstn.cfg /etc/kamailio/
COPY source/entrypoint_pstn.sh /
COPY source/entrypoint_webrtc.sh /
COPY source/certs/* /etc/kamailio/certs/
