# Grafana Admin Access & Global Loki Metric-to-Log Drilldown Plan

## Status: PLANNED — not applied. Do not deploy from this document.

## Objective

1. **Resolve Grafana access and login lockout**: Enable full interactive querying (Grafana Explore UI) by configuring anonymous access with the `Admin` role on the secure LAN/mesh (`fufu.land`).
2. **Implement universal Metric-to-Log Drill-Down**: Upgrade Vector log ingestion so systemd service units are indexed in Loki, allowing 1-click navigation from any Prometheus metric panel directly into correlated Loki logs.
3. **Expand DNS monitoring visibility**: Replace/supplement the 6-item line chart in the AdGuard dashboard with a full searchable table and direct drill-down links into the AdGuard query log and Loki.

---

## Current State

```text
┌───────────────────────────┐      ┌───────────────────────────┐
│     yirukou (Router)      │      │     yifuwuqi (Server)     │
│                           │      │                           │
│  • adguardhome + unbound  │      │  • adguardhome + unbound  │
│  • vector (journald)      │──┐   │  • prometheus (port 24090)│
│  • node/adguard exporters │  │   │  • loki (port 24100)      │
└───────────────────────────┘  │   │  • grafana (port 24030)   │
                               └──►│  • vector (journald)      │
                                   └───────────────────────────┘
```

1. **Grafana Authentication & Permissions** ([`modules/services/monitoring/grafana.nix`](file:///home/yi/the.files/nixos/modules/services/monitoring/grafana.nix)):
   - `auth.disable_login_form = true`: The login form is disabled.
   - `security.disable_initial_admin_creation = true`: No admin user exists.
   - `"auth.anonymous".org_role = "Viewer"`: All visitors are treated as read-only anonymous Viewers.
   - **Impact**: The user cannot log in, cannot use the **Explore** query builder, and cannot edit panels.

2. **Vector Log Shipping** ([`modules/services/monitoring/promtail.nix`](file:///home/yi/the.files/nixos/modules/services/monitoring/promtail.nix)):
   - Vector ships journald logs to Loki with only two static labels: `host = hostName` and `job = "systemd-journal"`.
   - `_SYSTEMD_UNIT` and `SYSLOG_IDENTIFIER` are not extracted as Loki stream labels.
   - **Impact**: In Grafana/Loki, searching for logs of a specific service requires a slow, unindexed regex scan over the entire host's journal stream (`{host="yifuwuqi"} |= "adguardhome"`).

3. **Dashboard Limitations & Lack of Drill-Down**:
   - [`vendor/adguard.json`](file:///home/yi/the.files/nixos/modules/services/monitoring/dashboards/vendor/adguard.json#L1302): Panel *🚫 Top Blocked Domains* uses `topk(10, adguard_top_blocked_domain_total{host="$host"})`, which truncates results to at most 10 (and renders fewer when only 6 are active within the range query window).
   - Systemd units, Nginx, and database dashboards have no Data Links pointing to Loki logs or external tools.

---

## Decisions

### 1. Authentication: Anonymous `Admin` vs Form Login

- **Decision**: Set `"auth.anonymous".org_role = "Admin"` in [`modules/services/monitoring/grafana.nix`](file:///home/yi/the.files/nixos/modules/services/monitoring/grafana.nix).
- **Rationale**:
  - Grafana is hosted on the private mesh (`grafana.fufu.land`), accessible only via LAN and Tailscale/NetBird.
  - Avoids credential management, session expiry, and login friction.
  - Immediately unlocks the visual **Explore** tab (query builder, metric browser, log inspector) and dashboard editing without a login prompt.

### 2. Vector Journald Log Label Enrichment

- **Decision**: In [`modules/services/monitoring/promtail.nix`](file:///home/yi/the.files/nixos/modules/services/monitoring/promtail.nix), add a Vector VRL `remap` transform before the Loki sink.
- **Labels to index in Loki**:
  - `host`: Machine hostname (`yifuwuqi` or `yirukou`).
  - `unit`: Systemd service unit (e.g. `adguardhome.service`, `nginx.service`, `forgejo.service`), sanitized to fallback to `syslog_identifier` or `"kernel"`.
- **Low-cardinality guardrail**:
  - Only `host` and `unit` are indexed as Loki stream labels (both have low cardinality: ~50 units per machine).
  - Message details, timestamps, and PIDs remain unindexed structured log fields to prevent Loki stream explosion.

### 3. Global Metric-to-Log Drill-Down Pattern

- **Decision**: Standardize Grafana **Data Links** across dashboards using the internal URL schema:
  ```text
  /explore?left={"datasource":"loki","queries":[{"expr":"{host=\"${__data.fields.host}\",unit=\"${__data.fields.name}\"}","refId":"A"}],"range":{"from":"${__from}","to":"${__to}"}}
  ```
- **Coverage**:
  - **Systemd Units & Services Overview**: Clicking any unit name opens Loki logs for that unit in the same time window.
  - **Nginx / Web**: Clicking 5xx/4xx error rate spikes opens `{host="$host", unit="nginx.service"} |~ "(4|5)[0-9]{2}"`.
  - **Fail2ban**: Clicking banned IP panels links to SSH/auth logs.

### 4. DNS Visibility & AdGuard Drill-Down

- **Decision**:
  1. In [`vendor/adguard.json`](file:///home/yi/the.files/nixos/modules/services/monitoring/dashboards/vendor/adguard.json), replace or supplement the *Top Blocked Domains* timeseries chart with a **Table Panel** running an instant query:
     ```promql
     sort_desc(adguard_top_blocked_domain_total{host="$host"})
     ```
     This displays **all** tracked blocked domains with built-in search and pagination.
  2. Add dual Data Links on domain fields:
     - **External Drilldown**: `https://adguard.fufu.land/#querylog?search=${__data.fields.domain}` (opens full raw query log with client devices and block rules).
     - **Internal Loki Drilldown**: `/explore?left={"datasource":"loki","queries":[{"expr":"{host=\"$host\",unit=\"adguardhome.service\"} |= \"${__data.fields.domain}\""}]}`.

---

## Phases

### Phase 1: Grafana Access Elevation
- **File**: `modules/services/monitoring/grafana.nix`
- Change `"auth.anonymous".org_role` from `"Viewer"` to `"Admin"`.
- Verify Grafana service configuration and restart Grafana on `yifuwuqi`.

### Phase 2: Vector Journald Log Label Enrichment
- **File**: `modules/services/monitoring/promtail.nix`
- Add a Vector transform:
  ```nix
  settings = {
    sources.journald.type = "journald";

    transforms.enrich_journal = {
      type = "remap";
      inputs = [ "journald" ];
      source = ''
        .unit = ._SYSTEMD_UNIT || .SYSLOG_IDENTIFIER || "system"
      '';
    };

    sinks.loki = {
      type = "loki";
      inputs = [ "enrich_journal" ];
      endpoint = "http://${centralHost.network.lan.ipv4.host}:${toString loki.port}";
      labels = {
        host = hostName;
        job = "systemd-journal";
        unit = "{{ unit }}";
      };
      encoding.codec = "text";
    };
  };
  ```
- Deployed to both `yifuwuqi` and `yirukou`.

### Phase 3: Dashboard Drill-Downs & Table Panel
- **Files**:
  - `modules/services/monitoring/dashboards/vendor/adguard.json`:
    - Add instant table query with domain search and AdGuard Query Log Data Link.
  - `modules/services/monitoring/dashboards/services-overview.nix`:
    - Add Data Link to jump directly into `{host="$host", unit="$service"}` in Loki.

---

## Rollout Order

1. **Verify configuration locally**:
   ```bash
   nix flake check
   ```
2. **Apply changes to `yifuwuqi`** (central monitoring server):
   ```bash
   sudo nixos-rebuild switch --flake .#yifuwuqi
   ```
   - Test `https://grafana.fufu.land`: Verify the **Explore** tab is visible and usable without login.
   - In Explore, verify Loki query `{host="yifuwuqi", unit="adguardhome.service"}` returns structured logs.
3. **Apply changes to `yirukou`** (router):
   ```bash
   # Run on yirukou:
   sudo nixos-rebuild switch --flake .#yirukou
   ```
   - Verify router journal logs arrive in Loki with `{host="yirukou", unit=...}`.

---

## Open Questions

1. **Anonymous Admin vs. Form Login**:
   - Is setting anonymous users to `Admin` acceptable to you since Grafana is private to your LAN and Tailscale, or would you prefer a formal login form with a persistent username and password generated via Sops?
2. **AdGuard Query Log Ingestion into Loki**:
   - AdGuard Home stores its full DNS query history in an internal SQLite database (`querylog.json`), while application events go to journald. The 1-click link to the AdGuard Web UI Query Log provides full client details instantly. Would you eventually want Vector to also parse and ingest raw query logs into Loki directly?
