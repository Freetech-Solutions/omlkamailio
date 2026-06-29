# Changelog: Rama oml-773-dev-oml-3 (Componente Kamailio)

## Resumen Ejecutivo
La rama `oml-773-dev-oml-3` marca una evolución estructural clave en la arquitectura de la plataforma OMniLeads hacia su versión 3.0, separando las responsabilidades de enrutamiento SIP en dos perfiles especializados: un proxy dedicado a WebRTC para agentes, y un Edge Proxy dedicado a la PSTN. Este cambio aporta alta disponibilidad, centralización del estado de los agentes mediante Redis, y mayor seguridad y eficiencia de enrutamiento hacia las redes públicas.

## Nuevas Funcionalidades (Features)
* **Perfilamiento Especializado:** Separación de la configuración original en dos servicios independientes: `kamailio_webrtc.cfg` para la gestión de clientes de agentes y `kamailio_pstn.cfg` como Edge Proxy telefónico.
* **Soporte de Balanceo y Failover (PSTN):** Implementación de balanceo de carga estático y dinámico de llamadas entrantes hacia los nodos de backend Asterisk utilizando el módulo `dispatcher` en el Edge Proxy.
* **Seguridad en Borde (PSTN):** Incorporación de listas de acceso (Allowlist) por IP de origen para los ITSPs, rechazando el tráfico no autorizado con un `403 Forbidden`.
* **Migración de Estado a Redis:** Almacenamiento distribuido del `usrloc` (registro y localización de agentes WebRTC) en Redis, logrando alta disponibilidad y compartición del estado de la plataforma global.

## Cambios Arquitectónicos / Técnicos

* **Múltiples Asterisk ACDs contactando a agentes vía Kamailio WebRTC:**
  Se introdujo la definición dinámica de la subred o IP interna de los Asterisk (`ACD_NET_ADDR`). La lógica en `kamailio_webrtc.cfg` está diseñada para confiar en el tráfico SIP tradicional (`SRC_SIP`) que proviene de esta red interna, evadiendo el desafío estricto de autenticación (401). Además, al persistir los registros de ubicación (Location) de los clientes WebRTC en Redis, cualquier nodo Asterisk ACD que pertenezca a la granja puede enviar la llamada a Kamailio sabiendo que este resolverá de forma centralizada hacia el agente final.

* **Introducción de `kamailio_pstn` como Edge Proxy:**
  Se introdujo este nuevo componente para actuar como frontera segura entre la red interna de PBXs Asterisk y los proveedores PSTN/ITSPs externos. Es un diseño multi-homed (escucha en interfaces públicas y privadas) que centraliza el manejo de NAT (vía RTPengine). Recibe tráfico desde los ITSPs, lo valida mediante listas blancas y lo balancea hacia los Asterisk. En el sentido inverso, los Asterisk envían su tráfico saliente mediante la cabecera `Route` hacia el Edge Proxy, el cual limpia la señalización y adapta el SDP (reemplazo de IPs) antes de entregar la llamada al ITSP público.

* **Nuevas Versiones de Kamailio:**
  Se actualizó el motor central a **Kamailio 6.0.5**. Para lograrlo, se renovó la base del contenedor a Debian Trixie (utilizando paquetes actualizados desde el repositorio oficial), y se incorporaron módulos y dependencias de sistema más recientes (como `kamailio-redis-modules` y `libhiredis1.1.0`) para habilitar la integración nativa con bases de datos en memoria.

## Impacto y Consideraciones para Despliegue

* **Consideraciones para DevOps:**
  * **Nuevas Variables de Entorno (PSTN):** Para el proxy PSTN se deberán inyectar nuevas variables obligatorias como `IPADDR_PUBLIC`, `IPADDR_PRIVATE`, `ACD_NODES` y `ITSP_NODES`, utilizadas en el arranque dinámico (`entrypoint_pstn.sh`) para construir las Allowlist y las reglas del `dispatcher`.
  * **Dependencia Crítica de Redis (WebRTC):** El despliegue de Kamailio WebRTC ahora requiere conectividad permanente a Redis (`REDIS_HOSTNAME`, puerto 6379, db 1). Sin esto, no existirá persistencia del `usrloc`.
  * **Cambios en Imágenes:** Se actualizó la lógica de construcción del `Dockerfile`. Ahora existen dos perfiles de ejecución dependientes del entrypoint o de la configuración montada. También se añade soporte con advertencias explícitas para procesadores ARM64 (Apple Silicon).

* **Consideraciones para QA:**
  * **Pruebas de Registro WebRTC (Múltiples Nodos):** Validar que agentes registrados mantengan su estado de forma distribuida, comprobando que múltiples nodos Asterisk logran enviarles llamadas eficientemente a través de la integración con Redis.
  * **Seguridad en PSTN:** Ejecutar casos de prueba simulando envíos de INVITE desde IPs de ITSP no declaradas en la variable `ITSP_NODES`, asegurando que el sistema devuelva el error `403`.
  * **Validación de Media y NAT:** Validar que RTPengine traduzca correctamente los flujos de audio (WebRTC <-> VoIP y VoIP <-> VoIP) en escenarios de NAT entre redes públicas y privadas, garantizando la ausencia de cortes o audios unidireccionales.
