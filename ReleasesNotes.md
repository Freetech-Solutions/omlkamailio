# Release Notes

## Unreleased

### Fixed

- Kamailio PSTN CrashLoop: reemplazar módulo `prometheus.so` por `xhttp_prom.so` (Kamailio 6.x), cargar `kex.so` (requerido por `xhttp_prom_pkg_stats`) y corregir allowlist ITSP para comparar solo IP en `$si` (sin puerto).

### Deploy / verificación

1. Reconstruir y publicar `KAMAILIO_IMG` desde `components-git-repo/kamailio/`.
2. Redeploy del servicio `kamailio_pstn.service` en el edge.
3. Arranque: `podman logs kamailio-pstn-server` — no debe fallar la carga de `prometheus.so`.
4. Métricas: `curl http://<IPADDR_PRIVATE>:9273/metrics` debe devolver métricas Prometheus.
5. Allowlist: en el contenedor, `/etc/kamailio/itsp_allowlist.cfg` debe usar IP sin puerto (p. ej. `if ($si == "35.244.12.86") return 1;`).
6. Inbound: INVITE desde IP ITSP permitida debe enrutar al dispatcher set 10, no `403 Forbidden`.

### Added

- Prometheus metrics endpoint on Kamailio PSTN (`tcp:IPADDR_PRIVATE:9273/metrics`) and WebRTC (`tcp:KAMAILIO_IFACE:9274/metrics`) via `prometheus` module. Rebuild and publish a new `KAMAILIO_IMG` tag before deploying to production.

2024-12-07

## Added

## Changed

- oml-659: Upgrade to kamailio 5.8. New Dockerfile multistage improve container img size.

## Fixed

## Removed
