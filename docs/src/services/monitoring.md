# Monitoring

The monitoring stack currently uses Netdata. The other monitoring modules are
placeholders for a future Prometheus/Grafana/Loki stack.

## Current Status

| Module | Status | Role |
| --- | --- | --- |
| `netdata.nix` | Implemented | Per-second host metrics and web UI. |
| `prometheus.nix` | Placeholder | Future time-series metrics server. |
| `grafana.nix` | Placeholder | Future dashboards. |
| `loki.nix` | Placeholder | Future log aggregation server. |
| `promtail.nix` | Placeholder | Future journald shipper. |
| `alertmanager.nix` | Placeholder | Future alert routing. |
| `exporters.nix` | Placeholder | Future node, nginx, mysqld, fail2ban, smartctl exporters. |

## Topology

`modules/services/monitoring/netdata.nix` supports parent and child modes
through `yi.netdata.childMode`.

Current deployment:

- `yirukou` runs Netdata parent mode.
- `yifuwuqi` runs Netdata child mode.
- The child streams metrics to `10.42.0.1:19999`.
- The parent allows streams from `10.42.0.2`.
- `netdata.fufu.land` is served by `nginx` on `yirukou` and proxies to
  `127.0.0.1:19999`.

## Access Control

`netdata.fufu.land` is protected by the shared HTTP basic-auth file:

- SOPS key: `services/htpasswd`
- Module: `modules/services/shared-auth.nix`
- Nginx consumer: `modules/services/nginx-proxy.nix`

Generate a new bcrypt entry with:

```sh
nix-shell -p apacheHttpd --run "htpasswd -nbB admin '<password>'"
```

Then paste the entry under `services.htpasswd` in the encrypted secrets file.

## Operational Notes

Netdata is configured with:

- `dbengine` memory mode
- 1-second update interval
- Python plugins disabled
- FreeIPMI plugin disabled
- Chrony synchronization wait before Netdata starts

Child mode binds the web UI to localhost only. Parent mode binds to all
interfaces but only allows direct web connections from localhost and
`10.42.0.*`; public browser access goes through nginx and basic auth.

## Source Files

- `modules/services/monitoring/netdata.nix`
- `hosts/yirukou/services.nix`
- `hosts/yifuwuqi/services.nix`
- `modules/services/nginx-proxy.nix`
- `modules/services/shared-auth.nix`
