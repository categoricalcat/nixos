# modules/services/monitoring

Observability stack for the fleet. Hosts opt in by importing the modules
they need.

## Status

| Module             | Status      | Role                                       |
| ------------------ | ----------- | ------------------------------------------ |
| `netdata.nix`      | Implemented | Per-second host metrics, web UI            |
| `prometheus.nix`   | Placeholder | Time-series metrics server                 |
| `grafana.nix`      | Placeholder | Dashboards (Prom + Loki datasources)       |
| `loki.nix`         | Placeholder | Log aggregation server                     |
| `promtail.nix`     | Placeholder | journald shipper to Loki (per host)        |
| `alertmanager.nix` | Placeholder | Alert routing (ntfy / Discord / email)     |
| `exporters.nix`    | Placeholder | node, nginx, mysqld, fail2ban, smartctl... |

The roadmap for the placeholders lives in
`.cursor/plans/monitoring stack follow-up.plan.md`.

## Auth

Web UIs are exposed via the existing nginx (`fufu.land` wildcard ACME)
and gated by HTTP basic auth using the shared htpasswd file declared in
`modules/services/shared-auth.nix` (sops key `services/htpasswd`).

Grafana, when added, will use its own login form instead of basic auth
to avoid double prompts.

## Topology (current)

- `yifuwuqi` runs Netdata on `127.0.0.1:19999`, fronted by nginx at
  `https://netdata.fufu.land`.
- `yixiaoqing` and `yitaishi` are not yet monitored. They join when the
  follow-up plan ships.
