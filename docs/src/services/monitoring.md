# Monitoring

The monitoring stack runs Netdata for realtime host debugging and a
Prometheus/Grafana/Loki stack for metrics, dashboards, and logs.

## Current Status

| Module | Status | Role |
| --- | --- | --- |
| `netdata.nix` | Implemented | Per-second host metrics and web UI. |
| `prometheus.nix` | Implemented | Central time-series metrics server on `yifuwuqi`. |
| `grafana.nix` | Implemented | Dashboards and provisioned Prometheus/Loki datasources. |
| `loki.nix` | Implemented | Central log aggregation server on `yifuwuqi`. |
| `promtail.nix` | Implemented | Vector-based journald shipper. |
| `alertmanager.nix` | Placeholder | Future alert routing. |
| `exporters.nix` | Implemented | Node, systemd, smartctl, nginx, and fail2ban exporters. |

## Topology

`modules/services/monitoring/netdata.nix` supports parent and child modes
through `yi.netdata.childMode`.

Current deployment:

- `yifuwuqi` runs Netdata parent mode.
- `yirukou` runs Netdata child mode.
- The child streams metrics to `10.42.0.2:19999`.
- The parent allows streams from `10.42.0.1`.
- LAN IPs come from `modules/addresses.nix`, not hardcoded literals.
- `netdata.fufu.land` is served by `nginx` on `yirukou` and proxies to
  `http://10.42.0.2:19999`.

Prometheus/Grafana/Loki deployment:

- Central host, proxy host, scrape hosts, and log hosts are defined in
  `modules/addresses.nix` under `monitoring`.
- The central host runs Prometheus, Loki, Grafana, local exporters, and Vector.
- The proxy host runs nginx, exporters, and Vector.
- Prometheus scrape jobs are generated from `exporter-metadata.nix`.
- Vector on each log host pushes journald logs to Loki with a `host` label.
- `grafana.fufu.land` is served by nginx on the proxy host and proxies to the
  central host's Grafana endpoint.

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

Prometheus/Grafana/Loki is configured with:

- Prometheus retention: 30 days.
- Loki retention: 7 days.
- Grafana datasource provisioning for Prometheus and Loki.
- Grafana uses anonymous Viewer access; only the required `secret_key` is a
  SOPS secret referenced through Grafana's file provider.
- Remote exporter ports are opened on the LAN interface for scrape hosts.
- Promtail is not used; local nixpkgs removed it after EOL, so Vector ships
  journald logs via structured Nix settings.

## Source Files

- `modules/services/monitoring/netdata.nix`
- `modules/services/monitoring/exporter-metadata.nix`
- `modules/services/monitoring/prometheus.nix`
- `modules/services/monitoring/grafana.nix`
- `modules/services/monitoring/loki.nix`
- `modules/services/monitoring/promtail.nix`
- `modules/services/monitoring/exporters.nix`
- `hosts/yirukou/services.nix`
- `hosts/yifuwuqi/services.nix`
- `modules/services/nginx-proxy.nix`
- `modules/services/shared-auth.nix`
