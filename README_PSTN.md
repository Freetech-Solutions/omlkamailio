# Kamailio PSTN Edge Proxy

## Overview

This repository contains the configuration for a Kamailio-based SIP edge proxy intended to run in a containerized environment (Docker/Podman). It sits between a pool of backend PBX nodes (Asterisk) and external SIP trunk providers (ITSPs), providing security controls, load balancing, and media handling via RTPengine.

The proxy is **multi-homed**: it listens on a public-facing address (ITSP traffic) and a private-facing address (internal backend traffic).

## Features

* **Dynamic configuration:** At startup, the entrypoint generates the dispatcher list and ITSP allowlist from environment variables.
* **Inbound load balancing:** Incoming PSTN calls are spread across backend nodes using the Kamailio `dispatcher` module.
* **Outbound routing:** Traffic from the internal network is forwarded toward the ITSP using `Route` headers (and related logic) from the backend.
* **ITSP IP allowlisting:** Inbound requests whose source IP is not listed are rejected with `403 Forbidden`.
* **NAT and media:** RTPengine rewrites SDP, bridges media between public and private sides where needed, and can strip WebRTC-oriented attributes (for example ICE) when talking to classic PSTN SIP peers.

## Deploy example

Minimal examples for running the published image. Adjust image tag, addresses, and ports for your environment.

### Docker (production-style)

With `--network host`, set the host’s public and private IPs (or the addresses you want Kamailio to bind and advertise).

```bash
docker run -it --rm --net=host \
  --name tel_pstn_proxy \
  -e IPADDR_PUBLIC="$PUBLIC_IP" \
  -e IPADDR_PRIVATE="$PRIVATE_IP" \
  -e FQDN="$PROXY_FQDN" \
  -e RTPENGINE_SOCKET="udp:${RTPENGINE_HOST}:${RTPENGINE_CONTROL_PORT}" \
  -e ACD_NODES="10.0.0.2,10.0.0.3" \
  -e ITSP_NODES="203.0.113.10,198.51.100.20" \
  omnileads/tel_pstn_proxy:${TAG}
```

### Systemd and Podman

Example unit (fix paths, user, and image tag as needed). The unit description should match this service, not RTPengine.

```ini
[Unit]
Description=Podman tel_pstn_proxy.service
Documentation=man:podman-generate-systemd(1)
Wants=network-online.target
After=network-online.target
RequiresMountsFor=%t/containers

[Service]
Environment=PODMAN_SYSTEMD_UNIT=%n
Restart=on-failure
TimeoutStopSec=70
ExecStartPre=/bin/rm -f %t/%n.ctr-id
ExecStart=/usr/bin/podman run \
  --cidfile=%t/%n.ctr-id \
  --cgroups=no-conmon \
  --rm \
  --sdnotify=conmon \
  --detach \
  --replace \
  --name=oml-tel_pstn_proxy-server \
  --network=host \
  -e IPADDR_PUBLIC="${PUBLIC_IP}" \
  -e IPADDR_PRIVATE="${PRIVATE_IP}" \
  -e FQDN="${PROXY_FQDN}" \
  -e RTPENGINE_SOCKET="udp:${RTPENGINE_HOSTNAME}:${RTPENGINE_PORT}" \
  -e ACD_NODES="${ACD_NODES}" \
  -e ITSP_NODES="${ITSP_NODES}" \
  --log-driver=journald \
  omnileads/tel_pstn_proxy:${TAG}
ExecStop=/usr/bin/podman stop --ignore --cidfile=%t/%n.ctr-id
ExecStopPost=/usr/bin/podman rm -f --ignore --cidfile=%t/%n.ctr-id
Type=notify
NotifyAccess=all
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

## Environment variables

Behavior is driven by variables passed into the container at start.

### Network and identity

* `IPADDR_PUBLIC` — Public IP address used on the ITSP-facing side (must match `listen` / advertise expectations when using host networking).
* `IPADDR_PRIVATE` — Private IP address used on the internal side toward Asterisk.
* `FQDN` — Fully qualified domain name (or primary hostname alias) substituted into Kamailio as `MY_FQDN` (for example `alias=`).
* `RTPENGINE_SOCKET` — RTPengine control socket, for example `udp:rtpengine:22222`.

### Routing and topology

* `ACD_NODES` — Comma-separated backend PBX nodes. Each entry is trimmed; optional `label=` prefix is stripped and only the host part is used. Supported host forms include plain `ip`, `ip:port`, or `sip:ip:port`. If no port is present, `ASTERISK_PORT` is appended (see below).
* `ITSP_NODES` — Comma-separated allowed ITSP source IPs for inbound checks. Same optional `label=` form as above; only the IP is compared to `$si`. If empty, the entrypoint warns and no ITSP source will match the allowlist.
* `ASTERISK_SETID` — Dispatcher set ID written as the first field of each line in `/etc/kamailio/dispatcher.list`. Default: `10`. **The stock `kamailio_pstn.cfg` selects set `10` for inbound (`ds_select_dst`); keep this default unless you change the routing script to use another set ID.**
* `ASTERISK_PORT` — Default SIP port for backends when the node does not include an explicit port. Default: `5060`.

### Performance tuning

* `SHM_SIZE` — Kamailio shared memory size in megabytes. Default: `64`.
* `PKG_SIZE` — Kamailio package (per-process) memory size in megabytes. Default: `8`.

## How it works

### 1. Initialization (`entrypoint_pstn.sh`)

On start, the entrypoint builds:

1. `/etc/kamailio/dispatcher.list` from `ACD_NODES`, using `ASTERISK_SETID` and `ASTERISK_PORT`.
2. `/etc/kamailio/itsp_allowlist.cfg` from `ITSP_NODES`, defining `route[IS_FROM_ITSP]` used as a strict source-IP gate for inbound PSTN traffic.

It then execs Kamailio with `kamailio_pstn.cfg`.

### 2. Inbound flow (ITSP → proxy → Asterisk)

1. **Receive:** An `INVITE` arrives on the public listener (`IPADDR_PUBLIC`).
2. **Allowlist:** `route[INBOUND_DISPATCH_FIXED]` calls `route[IS_FROM_ITSP]`. If the source IP does not match, Kamailio sends `403 Forbidden` and stops.
3. **Egress socket:** Outbound toward Asterisk is forced on the private socket (`force_send_socket(udp:MY_IP_ADDR_PRIVATE:5060)`).
4. **Load balancing:** `ds_select_dst` picks a destination from dispatcher set `10` (in the bundled config).
5. **Media:** If the `INVITE` carries SDP, `RTPENGINE_OFFER` runs before relaying to the backend.

### 3. Outbound flow (Asterisk → proxy → ITSP)

1. **Receive:** Asterisk sends traffic to the proxy’s private address (typically with this host as outbound proxy).
2. **INVITE classification:** Initial `INVITE` requests **without** the `OMniLeadsOutbound` header are treated as **inbound** from the PSTN and go through `INBOUND_DISPATCH_FIXED`. Outbound `INVITE` toward the ITSP is expected to include `OMniLeadsOutbound` so the request is not misclassified. `REGISTER` without that header is treated as outbound toward the provider.
3. **Routing:** For initial requests, Kamailio uses the `Route` header when present: it extracts the URI, sets `$du` (and for non-`REGISTER` methods adjusts `$ru`), removes `Route`, and relays. If there is no `Route`, it falls back to using `$ru` as the destination under certain checks.
4. **Media:** SDP is passed through `rtpengine_manage()` on offers with flags such as `replace-origin`, `replace-session-connection`, `ICE=remove`, and `RTP/AVP`, with extra force-replace variants when NAT tests indicate it.
5. **Relay:** The message is sent out via the public side toward the trunk.

### NAT and keepalives

* The dispatcher module probes backends (`ds_ping_interval=20`). With `mhomed=yes`, Kamailio can use the correct interface for those probes toward private nodes.
* `Record-Route` is used so in-dialog requests (for example `ACK`, `BYE`) continue to traverse the proxy as expected.

## Contributing

If your organization maintains a `CONTRIBUTING.md` for this project, follow that document for process and code of conduct.

## Authors

Fabian A. Pignataro and Fernando Montiel. See also the list of contributors for this repository.

## License

See the `LICENSE` file at the repository root (GNU Affero General Public License, version 3).
