# Migration Plan: fufu to aset (Zero-Downtime Domain & Brand Migration)

## Status: PROPOSED — waiting for user approval

## Objective

Migrate the primary homelab domain from `fufu.land` to `aset.love`, eradicating all instances of `fufu` across the repository (code, configurations, dotfiles, scripts, dashboards, and documentation) with **virtually zero service downtime**, **zero data loss**, and **zero git history rewrites**.

## Current state

Verified against the working tree (`rg -i "fufu"`):

- **176 occurrences across 38 files** (217 / 39 including this plan, which is retired on completion).
- `modules/addresses.nix`: 26 occurrences — 25 **hardcoded literals** (`domain = "git.fufu.land";` etc.) plus one comment (line 505). There is **no** `baseDomain` binding today.
- `modules/services/nginx-proxy.nix` (14) + `modules/services/proxy-vhosts.nix` (1): ACME email, `certs."fufu.land"`, static vhosts, one `useACMEHost = "fufu.land"`.
- `modules/services/adguardhome.nix`: 8 occurrences — rewrites and TLS cert path.
- Docs: **105 occurrences across 23 files** under `docs/src/` (including `fufu-service-ca`, `fufu-client-ca`, `/CN=Fufu Internal Service CA`).
- `users/assets/dotfiles/ssh/config`: 3 occurrences — `cloudflare.fufu.land` in **two** Host blocks (lines 34–35, 44).
- Remaining: `homepage.nix` (6), `adguardhome` vendored dashboard JSON (2), `webdav.nix` (2), `web-apps.nix` (2), `aliases.zsh` (2), `searxng.nix` (1), `forgejo.nix` (1), `sillytavern.nix` (1), `goaccess.nix` (1), `ci/auto-maintenance.sh` (1).
- Hardcoded domain literals also live **outside** `addresses.nix` (`nginx-proxy.nix`, `adguardhome.nix`, `proxy-vhosts.nix`, `webdav.nix`, `homepage.nix`, `searxng.nix`, `goaccess.nix`, `web-apps.nix`). All are Nix modules that already receive `allAddresses` via `_module.args` in `modules/common.nix` (`proxy-vhosts.nix` is imported with only `lib` today and must gain `allAddresses`).
- Hostnames (`yifuwuqi` etc.) contain `fuwu`, not `fufu` — **no host renames required**.
- Both domains are Cloudflare Registrar zones; deploys run via deploy-rs (`deploy .#<host>`).

## Decisions

1. **Dual-certificate staging**: provision the `aset.love` wildcard on `yirukou` *before* any vhost switches, so Nginx never references a missing cert (a naive single-commit switch would fail Nginx reload and take down every reverse-proxied service).
1. **Unhardcode the base domain repo-wide**: `modules/addresses.nix` gains a top-level `baseDomain = "aset.love";` attribute in its returned attrset (not a `let` binding), so every module reaches it via `allAddresses.baseDomain`. Its own 25 literals become `domain = "adguard.${baseDomain}";` style references, and every other Nix module replaces domain literals with `allAddresses.baseDomain` interpolation (dynamic attrset keys use `"${baseDomain}"` quoting; the `certs ? "fufu.land"` check in `adguardhome.nix` becomes `builtins.hasAttr baseDomain ...`). `proxy-vhosts.nix`'s import in `nginx-proxy.nix` gains `allAddresses`. Literals remain only where Nix cannot reach: vendored `adguard.json`, dotfiles, `ci/auto-maintenance.sh`, and prose comments. Single source of truth; future domain changes become one-line diffs.
1. **API token scope widened, not replaced** (Option A in Step 0.1): no SOPS secret churn.
1. **No git history rewrite**: all changes land as ordinary commits on top of history.
1. **This plan is retired** (deleted) in the final change set, per etiquette — also required for the zero-tolerance audit to pass.
1. **Legacy plan files updated in place** (user call): the 3 other plans under `docs/src/plans/` get their `fufu` occurrences migrated, not retired.
1. **No AdGuard grace period**: `fufu.land` rewrites are purged in Phase 3. The Phase 1 dual-rewrite staging is what prevents downtime — a grace period would only serve stale *unmanaged* clients with hardcoded `fufu.land` entries, and the entire LAN fleet is flake-managed (updated in Phase 4). Full migration with zero downtime is possible without it.
1. **The `ffsh` ssh alias is deleted outright** — no `assh` replacement; the alias line is removed from `aliases.zsh`.

## 1. Phases — Zero-Downtime Architecture & Strategy

```text
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 0: External Setup (Cloudflare Dashboard & Zero Trust)            │
│ • Cloudflare API Token: Ensure zone scope includes aset.love           │
│ • Cloudflare Tunnel: Add cloudflare.aset.love -> SSH on same tunnel    │
│ • SSL/TLS mode: confirm Full (strict) on the aset.love zone            │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 1: Gateway Staging (Dual Certificate & Dual DNS on yirukou)      │
│ • addresses.nix gains top-level baseDomain attr (no-op for services)   │
│ • yirukou requests security.acme.certs."aset.love" via DNS-01          │
│ • fufu.land remains 100% active and serving traffic                    │
│ • AdGuard Home resolves BOTH *.fufu.land and *.aset.love -> 10.42.0.1  │
│ ➔ DOWNTIME: 0 seconds                                                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 2: Core Server Cutover (yifuwuqi)                                │
│ • Switch addresses.nix literals to ${baseDomain} references            │
│ • yifuwuqi local ingress updates Host routing to *.aset.love           │
│ • Rebuild & switch yifuwuqi                                            │
│ ➔ DOWNTIME: ~1-2 seconds (instant systemd reload of local ingress)     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 3: Gateway Cutover (yirukou Reverse Proxy)                       │
│ • Nginx virtual hosts switch useACMEHost = "aset.love"                 │
│ • Valid *.aset.love cert is already on disk; Nginx reloads cleanly     │
│ • Rebuild & switch yirukou                                             │
│ ➔ DOWNTIME: ~0.5 seconds (Nginx graceful reload)                       │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 4: Desktop Fleet, Git Remotes & Client Migration                 │
│ • Update git origin remote URL to git.aset.love                        │
│ • Deploy yitaishi, yixiaoqing, yichuang (Attic cache: cache.aset.love) │
│ • Update user dotfiles (ssh/config, aliases.zsh)                       │
│ ➔ DOWNTIME: 0 seconds                                                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 5: Final Purge & Verification (Eradicate all "fufu")             │
│ • Remove legacy fufu.land cert & rewrites                              │
│ • Update all docs/src/ files, vendor dashboards, and CI scripts        │
│ • Delete this plan file (retired)                                      │
│ • Run automated audit: rg -i "fufu" -> 0 matches                       │
│ ➔ DOWNTIME: 0 seconds                                                  │
└────────────────────────────────────────────────────────────────────────┘
```

## 2. Global Scope & File Inventory

All 176 occurrences (38 files) migrate to `aset` (preserving git commit history):

1. **Central Domain Registry (`modules/addresses.nix`)** — 26 occurrences: hardcoded literals replaced via new `baseDomain` binding (Decision 2).
1. **Reverse Proxy & ACME (`modules/services/nginx-proxy.nix`, `proxy-vhosts.nix`)** — 15 occurrences: ACME email, cert names, `useACMEHost`, and static vhosts all become `allAddresses.baseDomain` references (Decision 2); `proxy-vhosts.nix`'s import gains `allAddresses`.
1. **Internal Edge DNS (`modules/services/adguardhome.nix`)** — 8 occurrences: rewrites, server name, TLS paths, and the `certs ?` guard all become `allAddresses.baseDomain` references (Decision 2).
1. **Standalone Modules & Dashboards**:
   - `modules/services/homepage.nix` (6): service URLs and search widget become `allAddresses.baseDomain` references (Decision 2).
   - `modules/services/searxng.nix` (1): `base_url` becomes an `allAddresses.baseDomain` reference.
   - `modules/services/webdav.nix` (2): vhost name and `useACMEHost` become `allAddresses.baseDomain` references.
   - `hosts/yirukou/goaccess.nix` (1): `--ws-url` becomes an `allAddresses.baseDomain` reference.
   - `modules/desktop/web-apps.nix` (2): app URLs become `allAddresses.baseDomain` references.
   - `modules/services/monitoring/dashboards/vendor/adguard.json` (2): drilldown links `https://adguard.aset.love/#logs...` (vendored JSON — stays literal, Decision 2).
   - `modules/services/ai/sillytavern.nix` (1): comment `companion.aset.love`.
   - `modules/services/forgejo.nix` (1): comment `git.aset.love`.
1. **Dotfiles, Scripts & Git Remote**:
   - `users/assets/dotfiles/ssh/config` (3): `cloudflare.aset.love` in both Host blocks.
   - `users/assets/dotfiles/zsh/aliases.zsh` (2): delete the `ffsh` alias line entirely (Decision 8).
   - `ci/auto-maintenance.sh` (1): `user.email "auto-maintenance@aset.love"`.
   - Local working repository git remote: `origin ssh://forgejo@git.aset.love:24212/yi/nixos.git`.
1. **Documentation (`docs/src/`)** — 105 occurrences across 23 files, including `fufu-service-ca` $\\to$ `aset-service-ca`, `/CN=Fufu Internal Service CA` $\\to$ `/CN=Aset Internal Service CA`, and `fufu-client-ca` $\\to$ `aset-client-ca`. (Counts include 3 other plan files: `mtls-architecture-plan.md`, `architecture-rollout-plan.md`, `impermanence-yirukou-plan.md` — all updated in place, Decision 6.)

## 3. Rollout Order & Step-by-Step Instructions

### Step 0: Manual External Prerequisites (Cloudflare Dashboard)

Both domains are registered with Cloudflare Registrar. `aset.love` is an active zone managed by Cloudflare nameservers. Perform the following three manual configurations:

#### 0.1 Cloudflare API Token Scope

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com) $\\to$ Top right profile icon $\\to$ **My Profile** $\\to$ **API Tokens**.
1. Find the API token used for ACME (`cloudflare_api_token`). Click **Edit**:
   - **Option A (Recommended — Zero Secret Churn)**: Under **Zone Resources**, change the scope from `Specific zone: fufu.land` to **Include $\\to$ All zones from an account $\\to$ [Your Account]** (or add `aset.love` to the list). Click **Continue to summary** $\\to$ **Update Token**.
     - *Result*: No SOPS secret changes or re-encryption required!
   - **Option B (Separate Token)**: If creating a new token, set Permissions: `Zone:DNS:Edit` on `Zone:aset.love`.
     - *SOPS Recipe*: On `yifuwuqi`, run `su -`, then `cd /home/yi/the.files/nixos && sops secrets/secrets.yaml`. Update `cloudflare_api_token: | CLOUDFLARE_DNS_API_TOKEN=<new-token>`, save, and exit. (User task — agents never run `sops`.)

#### 0.2 Cloudflare Zero Trust Tunnel (SSH Fail-Safe)

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com) $\\to$ **Networks** $\\to$ **Tunnels**.
1. Click your existing tunnel (running on `yifuwuqi`) $\\to$ **Configure** $\\to$ **Public Hostnames** tab.
1. Click **Add a public hostname**:
   - **Subdomain**: `cloudflare`
   - **Domain**: `aset.love`
   - **Service**: `SSH`
   - **URL**: `10.42.0.2:24212` (or `127.0.0.1:24212`)
1. Click **Save hostname**.
   - *Result*: Cloudflare automatically creates the public CNAME record for `cloudflare.aset.love`. Both `cloudflare.fufu.land` and `cloudflare.aset.love` now route through the existing tunnel simultaneously.

#### 0.3 SSL/TLS Mode

1. In Cloudflare Dashboard, select `aset.love` $\\to$ **SSL/TLS** $\\to$ **Overview**.
1. Confirm the encryption mode is set to **Full (strict)**.

### Step 1: Gateway Staging (`yirukou`) — Zero Downtime

Provision the wildcard `aset.love` certificate and add dual DNS rewrites without altering any active `fufu.land` service vhosts.

1. **Introduce `baseDomain` in `modules/addresses.nix`**: add the top-level `baseDomain = "aset.love";` attribute (Decision 2). No existing literal is touched yet, so this deploy is a pure no-op for running services.
1. **Apply Staging Diff to `modules/services/nginx-proxy.nix`**:
   - Add `certs."${allAddresses.baseDomain}"` alongside `certs."fufu.land"`.
1. **Apply Staging Diff to `modules/services/adguardhome.nix`**:
   - Add rewrites for `*.${baseDomain}`, `${baseDomain}`, `smb.${baseDomain}`, `ssh.${baseDomain}` alongside existing `fufu.land` rewrites.
1. **Verify evaluation**:
   ```bash
   nix eval .#nixosConfigurations.yirukou.config.system.build.toplevel.drvPath
   ```
1. **Deploy to Gateway (`yirukou`)** (user runs):
   ```bash
   deploy .#yirukou
   # or on yirukou: sudo nixos-rebuild switch --flake .#yirukou
   ```
1. **Verify Certificate Issuance on `yirukou`**:
   ```bash
   ai-ssh yirukou systemctl status acme-aset.love.service
   ai-ssh yirukou test -f /var/lib/acme/aset.love/fullchain.pem && echo "ACME cert for aset.love verified on disk!"
   ```
1. **Verify LAN DNS Rewrites**:
   ```bash
   dig @10.42.0.1 home.aset.love +short
   # Output must be: 10.42.0.1
   ```

### Step 2: Core Server Cutover (`yifuwuqi`)

Now that the gateway can resolve and terminate `aset.love`, update `yifuwuqi`'s service definitions.

1. **Apply Code Changes**:
   - `modules/addresses.nix`: rewrite all 25 literals to `${baseDomain}` references (the binding itself landed in Step 1 — this is the actual cutover).
   - `modules/services/searxng.nix`, `homepage.nix`, `webdav.nix`: replace literals with `allAddresses.baseDomain` references (Decision 2); `adguard.json`: literal link updates.
1. **Verify evaluation**:
   ```bash
   nix eval .#nixosConfigurations.yifuwuqi.config.system.build.toplevel.drvPath
   ```
1. **Deploy to Core Server (`yifuwuqi`)** (user runs):
   ```bash
   deploy .#yifuwuqi
   # or on yifuwuqi: sudo nixos-rebuild switch --flake .#yifuwuqi
   ```
1. **Verify Backend Health**:
   ```bash
   ai-ssh yifuwuqi systemctl is-active postgresql forgejo atticd grafana nginx
   ```

### Step 3: Gateway Cutover (`yirukou`) & Total Purge of `fufu` in Configs

With the backend ready, switch Nginx reverse proxy vhosts and AdGuard Home TLS to `aset.love`, and purge all legacy `fufu.land` vhosts.

1. **Apply Code Changes** (all via `allAddresses.baseDomain` references, Decision 2):
   - `modules/services/proxy-vhosts.nix`: `useACMEHost = baseDomain;` (import gains `allAddresses`).
   - `modules/services/nginx-proxy.nix`: remove `certs."fufu.land"`; ACME email and static vhosts reference `baseDomain`.
   - `modules/services/adguardhome.nix`: remove legacy `fufu.land` rewrites; TLS paths and the `certs` guard reference `baseDomain`.
   - `hosts/yirukou/goaccess.nix`: WebSocket URL references `baseDomain`.
1. **Verify evaluation**:
   ```bash
   nix eval .#nixosConfigurations.yirukou.config.system.build.toplevel.drvPath
   ```
1. **Deploy to Gateway (`yirukou`)** (user runs):
   ```bash
   deploy .#yirukou
   ```
1. **Verify HTTPS Ingress**:
   ```bash
   curl -Ik https://home.aset.love
   curl -Ik https://git.aset.love
   curl -Ik https://grafana.aset.love
   curl -Ik https://cache.aset.love/yi/nix-cache-info
   ```

### Step 4: Client & Desktop Fleet Rollout

1. **Update Local Git Remote**:
   ```bash
   git remote set-url origin ssh://forgejo@git.aset.love:24212/yi/nixos.git
   git fetch origin
   ```
1. **Apply Code Changes**:
   - `modules/desktop/web-apps.nix`: app URLs reference `allAddresses.baseDomain` (Decision 2).
1. **Update User Dotfiles**:
   - `users/assets/dotfiles/ssh/config`: change `cloudflare.fufu.land` to `cloudflare.aset.love` in **both** Host blocks (3 occurrences).
   - `users/assets/dotfiles/zsh/aliases.zsh`: delete the `ffsh` alias line (both `fufu.land` references go with it).
1. **Deploy Desktop Clients** (user runs):
   ```bash
   deploy .#yitaishi
   deploy .#yixiaoqing
   # yichuang (WSL): rebuild locally inside WSL
   ```
1. **Verify Client Operations**:
   - Test SSH fallback: `ssh cloudflare.aset.love`
   - Test Attic binary cache pull on client: `nix path-info --store https://cache.aset.love/yi ...`

### Step 5: Documentation, Plan Retirement & Final Audit

1. **Update all 23 documents under `docs/src/`** (105 occurrences):
   - Replace all occurrences of `fufu.land` with `aset.love`.
   - Replace `fufu-service-ca` with `aset-service-ca`.
   - Replace `fufu-client-ca` with `aset-client-ca`.
   - Replace `/CN=Fufu Internal Service CA` with `/CN=Aset Internal Service CA`.
1. **Update CI Maintenance script**:
   - `ci/auto-maintenance.sh`: update git commit email to `auto-maintenance@aset.love`.
1. **Retire this plan**: delete `docs/src/plans/aset-love-migration-plan.md` in the same change set that completes the migration.
1. **Run Zero-Tolerance Audit**:
   ```bash
   rg -i "fufu"
   # Must return 0 matches across the working tree!
   ```

## 4. Rollback Strategy

If any failure occurs during staging or cutover:

- **Phase 1 failure**: If ACME issuance fails on `yirukou`, `fufu.land` was untouched; simply inspect Lego logs (`ai-ssh yirukou journalctl -u acme-aset.love.service`).
- **Phase 2/3 rollback**: User runs `deploy .#yirukou --rollback` (or `sudo nixos-rebuild switch --rollback`). Nginx and AdGuard immediately revert to the previous working generation.

## Open questions

None — all resolved during review (Decisions 6–8).
