# AdGuard Grafana Dashboard Layout Plan

## Objective

Fix the asymmetric and gapped layout in the AdGuard Grafana dashboard (`modules/services/monitoring/dashboards/vendor/adguard.json`) so that `🚫 Block Reasons` and `🚫 Top Blocked Domains` sit side-by-side, `🔍 DNS Query Types` and `🌍 Top Queried Domains` sit side-by-side, and no empty gaps remain.

## Current State

- `🔍 DNS Query Types` (id 6) is at `gridPos: { h: 9, w: 12, x: 0, y: 6 }` with empty space at `x=12`.
- `🚫 Block Reasons` (id 7) is at `gridPos: { h: 9, w: 12, x: 0, y: 33 }` paired with `🌍 Top Queried Domains` (id 8) at `x=12`.
- `🚫 Top Blocked Domains` (id 10) is at `gridPos: { h: 11, w: 12, x: 0, y: 42 }` with empty space at `x=12`.
- "Latency Data Monitoring" row starts at `y=64`, leaving an 11-unit dead vertical gap.

## Decisions

1. Pair `🔍 DNS Query Types` (id 6, left) and `🌍 Top Queried Domains` (id 8, right) at `y=6` (`w=12, h=9`).
2. Pair `🚫 Block Reasons` (id 7, left) and `🚫 Top Blocked Domains` (id 10, right) at `y=33` (`w=12, h=9`).
3. Compact subsequent sections ("Latency Data Monitoring" row to `y=42`, "Exporter Healths" to `y=59`).
4. Set `Exporter Cache Size` (id 32) width to `w=12, h=8` at `x=12, y=60` to cleanly fill the row alongside `id: 22` (w=4, h=4), `id: 25` (w=4, h=4), and `id: 24` (w=8, h=8).

## Phases

1. Update `modules/services/monitoring/dashboards/vendor/adguard.json` gridPos values and panel array ordering.
2. Validate JSON syntax and Nix configuration evaluation.
3. Provide deployment command to the user.

## Rollout Order

- Machine target: `yifuwuqi` (where Grafana runs).
- Command for user: `nixos-rebuild switch --flake .#yifuwuqi`.

## Open Questions

None.
