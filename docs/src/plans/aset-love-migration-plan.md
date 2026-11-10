# Migration Plan: fufu to aset (Zero-Downtime Domain & Brand Migration)

## Status: PROPOSED — waiting for user approval

## Objective

Migrate the primary homelab domain from `fufu.land` to `aset.love`, eradicating all instances of `fufu` across the repository (code, configurations, dotfiles, scripts, dashboards, and documentation) with **virtually zero service downtime**, **zero data loss**, and **zero git history rewrites**. Legacy URLs keep working forever: `*.fufu.land` (and the apex) permanently 301-redirects to its `*.aset.love` counterpart (Decision 8).

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

1. **Legacy AdGuard rewrites are kept, not purged** (amended by Decision 8): the four `fufu.land` rewrites survive Phase 3 as `legacyDomain` references — they are the DNS leg of the permanent redirect (LAN clients resolve old names to the gateway, and Nginx 301s them). The Phase 1 dual-rewrite staging is still what prevents downtime during the migration itself.

1. **Permanent 301 redirect from `*.fufu.land` to `*.aset.love`**: old links, bookmarks, and hardcoded URLs keep working indefinitely. `modules/addresses.nix` gains a top-level `legacyDomain = "fufu.land";` attribute — the single intentional `fufu` literal left in the repo (SSOT, mirroring Decision 2) — referenced forever by three things:

   - `security.acme.certs."${legacyDomain}"` on `yirukou` (HTTPS 301s require a valid legacy cert; the Cloudflare API token must retain `fufu.land` zone access for renewals — Option A in Step 0.1 already grants all zones);
   - the four legacy AdGuard rewrites (Decision 7);
   - two Nginx vhosts on `yirukou`: a regex server `~^(?<sub>.+)\.fufu\.land$` returning `301 https://$sub.aset.love$request_uri` (subdomain- and path-preserving), and the apex returning `301 https://aset.love$request_uri` — both `useACMEHost = legacyDomain; forceSSL = true;`.

   Accepted trade-off: DoH clients pinned to `https://dns.fufu.land/dns-query` will not follow the 301 — the fleet is flake-managed and picks up `dns.aset.love` in Phase 4. Step 5.4's audit expects exactly the `legacyDomain` literal.

1. **The `ffsh` ssh alias is deleted outright** — no `assh` replacement; the alias line is removed from `aliases.zsh`.

1. **Multi-session AI Copilot execution**: the AI acts as an interactive step-by-step copilot across sessions — orienting on current progress, asking what the user did, giving clear instructions for what to do next, verifying outcomes, and checking off `[x]` items in this plan after each step so work can pause and resume at any point until the plan is retired in Step 5.

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
│ • Legacy *.fufu.land vhosts become permanent 301 redirects             │
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
│ Phase 5: Final Cleanup & Verification                                  │
│ • Keep legacy cert & rewrites — permanent 301 redirects (Decision 8)   │
│ • Update all docs/src/ files, vendor dashboards, and CI scripts        │
│ • Delete this plan file (retired)                                      │
│ • Run audit: rg -i "fufu" -> only the legacyDomain literal remains     │
│ ➔ DOWNTIME: 0 seconds                                                  │
└────────────────────────────────────────────────────────────────────────┘
```

## 2. Global Scope & File Inventory

All 176 occurrences (38 files) migrate to `aset` (preserving git commit history). One intentional `fufu.land` literal remains forever — `legacyDomain` in `modules/addresses.nix` (Decision 8):

1. **Central Domain Registry (`modules/addresses.nix`)** — 26 occurrences: hardcoded literals replaced via new `baseDomain` binding (Decision 2); gains one intentional permanent literal, `legacyDomain = "fufu.land";` (Decision 8).
1. **Reverse Proxy & ACME (`modules/services/nginx-proxy.nix`, `proxy-vhosts.nix`)** — 15 occurrences: ACME email, cert names, `useACMEHost`, and static vhosts all become `allAddresses.baseDomain` references (Decision 2); `proxy-vhosts.nix`'s import gains `allAddresses`. The legacy cert and two permanent 301 redirect vhosts reference `allAddresses.legacyDomain` (Decision 8).
1. **Internal Edge DNS (`modules/services/adguardhome.nix`)** — 8 occurrences: rewrites, server name, TLS paths, and the `certs ?` guard all become `allAddresses.baseDomain` references (Decision 2). The four legacy `fufu.land` rewrites are kept as `legacyDomain` references (Decision 8).
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
   - `users/assets/dotfiles/zsh/aliases.zsh` (2): delete the `ffsh` alias line entirely (Decision 9).
   - `ci/auto-maintenance.sh` (1): `user.email "auto-maintenance@aset.love"`.
   - Local working repository git remote: `origin ssh://forgejo@git.aset.love:24212/yi/nixos.git`.
1. **Documentation (`docs/src/`)** — 105 occurrences across 23 files, including `fufu-service-ca` $\\to$ `aset-service-ca`, `/CN=Fufu Internal Service CA` $\\to$ `/CN=Aset Internal Service CA`, and `fufu-client-ca` $\\to$ `aset-client-ca`. (Counts include 3 other plan files: `mtls-architecture-plan.md`, `architecture-rollout-plan.md`, `impermanence-yirukou-plan.md` — all updated in place, Decision 6.)

## 3. Rollout Order & Step-by-Step Instructions

### AI Copilot Session Protocol (Multi-Session Interactive Execution)

This migration is designed to be executed interactively across multiple sessions with the AI acting as a step-by-step copilot:

1. **Session Start Trigger (`"we are running @docs/src/plans/aset-love-migration-plan.md"`)**:
   At the beginning of each session, the user says `"we are running @docs/src/plans/aset-love-migration-plan.md"`. The AI immediately reads this file, inspects the `[ ]` / `[x]` checkboxes below (plus `git status` / `git diff`), and replies with a concise 3-part status briefing:
   - **What we are doing**: The migration objective and the active Phase/Step.
   - **Where we are**: Which `[x]` steps are already done, current working-tree state, and — if a `(User)` step was last in flight — asking: *"What did you do since last session, and did it succeed?"*
   - **Where we are going**: The immediate next unchecked `[ ]` step and the upcoming verification gate.
1. **Guide Step-by-Step ("What should I do next?")**: The AI works **one step or phase gate at a time** — never jumping past a manual dashboard action or host deployment before it is confirmed and verified:
   - **AI tasks** (Nix/config edits, `nix eval`, read-only `ai-ssh` / `dig` / `curl` / `rg` checks): the AI performs the change or check, shows the diff/output, and updates the checkbox to `[x]`.
   - **User tasks** (Cloudflare Dashboard steps, `deploy .#<host>`, `git remote`, `git commit`): the AI gives exact instructions and commands for the single current step, pauses, and asks: *"What did you do, and did it succeed?"*
1. **Checkpoint ("What did I do?")**: As soon as a step or verification gate passes, the AI marks its checkbox `[x]` in this file (and updates `Status:` at the top if pausing between phases) so the next session can pick up seamlessly from the exact next unchecked item.

### Step 0: Manual External Prerequisites (Cloudflare Dashboard)

Both domains are registered with Cloudflare Registrar. `aset.love` is an active zone managed by Cloudflare nameservers. Perform the following three manual configurations:

#### 0.1 Cloudflare API Token Scope

- [x] **0.1.1** Log in to [Cloudflare Dashboard](https://dash.cloudflare.com) $\\to$ Top right profile icon $\\to$ **My Profile** $\\to$ **API Tokens**.
- [x] **0.1.2** Find the API token used for ACME (`cloudflare_api_token`). Click **Edit**:
  - **Option A (Recommended — Zero Secret Churn)**: Under **Zone Resources**, change the scope from `Specific zone: fufu.land` to **Include $\\to$ All zones from an account $\\to$ [Your Account]** (or add `aset.love` to the list). Click **Continue to summary** $\\to$ **Update Token**.
    - *Result*: No SOPS secret changes or re-encryption required!
  - **Option B (Separate Token)**: If creating a new token, set Permissions: `Zone:DNS:Edit` on `Zone:aset.love`.
    - *SOPS Recipe*: On `yifuwuqi`, run `su -`, then `cd /home/yi/the.files/nixos && sops secrets/secrets.yaml`. Update `cloudflare_api_token: | CLOUDFLARE_DNS_API_TOKEN=<new-token>`, save, and exit. (User task — agents never run `sops`.)

#### 0.2 Cloudflare Zero Trust Tunnel (SSH Fail-Safe)

- [x] **0.2.1** Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com) $\\to$ **Networks** $\\to$ **Tunnels**.
- [x] **0.2.2** Click your existing tunnel (running on `yifuwuqi`) $\\to$ **Configure** $\\to$ **Public Hostnames** tab.
- [x] **0.2.3** Click **Add a public hostname**:
  - **Subdomain**: `cloudflare`
  - **Domain**: `aset.love`
  - **Service**: `SSH`
  - **URL**: `10.42.0.2:24212` (or `127.0.0.1:24212`)
- [x] **0.2.4** Click **Save hostname**.
  - *Result*: Cloudflare automatically creates the public CNAME record for `cloudflare.aset.love`. Both `cloudflare.fufu.land` and `cloudflare.aset.love` now route through the existing tunnel simultaneously.

#### 0.3 SSL/TLS Mode

- [x] **0.3.1** In Cloudflare Dashboard, select `aset.love` $\\to$ **SSL/TLS** $\\to$ **Overview**.
- [x] **0.3.2** Confirm the encryption mode is set to **Full (strict)**.

### Step 1: Gateway Staging (`yirukou`) — Zero Downtime

Provision the wildcard `aset.love` certificate and add dual DNS rewrites without altering any active `fufu.land` service vhosts.

- [x] **1.1 Introduce `baseDomain` in `modules/addresses.nix`** (AI): add the top-level `baseDomain = "aset.love";` attribute (Decision 2). No existing literal is touched yet, so this deploy is a pure no-op for running services.
- [x] **1.2 Apply Staging Diff to `modules/services/nginx-proxy.nix`** (AI):
  - Add `certs."${allAddresses.baseDomain}"` alongside `certs."fufu.land"`.
- [x] **1.3 Apply Staging Diff to `modules/services/adguardhome.nix`** (AI):
  - Add rewrites for `*.${baseDomain}`, `${baseDomain}`, `smb.${baseDomain}`, `ssh.${baseDomain}` alongside existing `fufu.land` rewrites.
- [x] **1.4 Verify evaluation** (AI):
  ```bash
  nix eval .#nixosConfigurations.yirukou.config.system.build.toplevel.drvPath
  ```
- [ ] **1.5 Deploy to Gateway (`yirukou`)** (User runs, AI waits for confirmation):
  ```bash
  deploy .#yirukou
  # or on yirukou: sudo nixos-rebuild switch --flake .#yirukou
  ```
- [ ] **1.6 Verify Certificate Issuance on `yirukou`** (AI):
  ```bash
  ai-ssh yirukou systemctl status acme-aset.love.service
  ai-ssh yirukou test -f /var/lib/acme/aset.love/fullchain.pem && echo "ACME cert for aset.love verified on disk!"
  ```
- [ ] **1.7 Verify LAN DNS Rewrites** (AI):
  ```bash
  dig @10.42.0.1 home.aset.love +short
  # Output must be: 10.42.0.1
  ```

### Step 2: Core Server Cutover (`yifuwuqi`)

Now that the gateway can resolve and terminate `aset.love`, update `yifuwuqi`'s service definitions.

- [ ] **2.1 Apply Code Changes** (AI):
  - `modules/addresses.nix`: rewrite all 25 literals to `${baseDomain}` references (the binding itself landed in Step 1 — this is the actual cutover).
  - `modules/services/searxng.nix`, `homepage.nix`, `webdav.nix`: replace literals with `allAddresses.baseDomain` references (Decision 2); `adguard.json`: literal link updates.
- [ ] **2.2 Verify evaluation** (AI):
  ```bash
  nix eval .#nixosConfigurations.yifuwuqi.config.system.build.toplevel.drvPath
  ```
- [ ] **2.3 Deploy to Core Server (`yifuwuqi`)** (User runs, AI waits for confirmation):
  ```bash
  deploy .#yifuwuqi
  # or on yifuwuqi: sudo nixos-rebuild switch --flake .#yifuwuqi
  ```
- [ ] **2.4 Verify Backend Health** (AI):
  ```bash
  ai-ssh yifuwuqi systemctl is-active postgresql forgejo atticd grafana nginx
  ```

### Step 3: Gateway Cutover (`yirukou`) & Legacy-Domain Redirect

With the backend ready, switch Nginx reverse proxy vhosts and AdGuard Home TLS to `aset.love`, and replace all legacy `fufu.land` vhosts with permanent 301 redirects (Decision 8).

- [ ] **3.1 Apply Code Changes** (AI — new services via `allAddresses.baseDomain`, legacy redirect via `allAddresses.legacyDomain`; Decisions 2 & 8):
  - `modules/addresses.nix`: add top-level `legacyDomain = "fufu.land";` — the repo's only intentional remaining `fufu` literal.
  - `modules/services/proxy-vhosts.nix`: `useACMEHost = baseDomain;` (import gains `allAddresses`).
  - `modules/services/nginx-proxy.nix`: ACME email and static vhosts reference `baseDomain`; `certs."fufu.land"` is **kept**, renamed to `certs."${legacyDomain}"`; add two redirect vhosts — regex `~^(?<sub>.+)\.fufu\.land$` → `return 301 https://$sub.aset.love$request_uri;` and apex `fufu.land` → `301 https://aset.love$request_uri` (both `useACMEHost = legacyDomain; forceSSL = true;`).
  - `modules/services/adguardhome.nix`: legacy `fufu.land` rewrites are **kept** as explicit `${legacyDomain}` entries (`smb.`, `ssh.`, wildcard, apex — `ssh.` becomes explicit because `addresses.nix`'s `ssh.domain` flipped to `baseDomain` in Step 2.1); TLS paths and the `certs` guard reference `baseDomain`.
  - `hosts/yirukou/goaccess.nix`: WebSocket URL references `baseDomain`.
- [ ] **3.2 Verify evaluation** (AI):
  ```bash
  nix eval .#nixosConfigurations.yirukou.config.system.build.toplevel.drvPath
  ```
- [ ] **3.3 Deploy to Gateway (`yirukou`)** (User runs, AI waits for confirmation):
  ```bash
  deploy .#yirukou
  ```
- [ ] **3.4 Verify HTTPS Ingress** (AI):
  ```bash
  curl -Ik https://home.aset.love
  curl -Ik https://git.aset.love
  curl -Ik https://grafana.aset.love
  curl -Ik https://cache.aset.love/yi/nix-cache-info
  curl -sI https://git.fufu.land -o /dev/null -w '%{http_code} %{redirect_url}\n'
  # Expected: 301 https://git.aset.love/
  ```

### Step 4: Client & Desktop Fleet Rollout

- [ ] **4.1 Update Local Git Remote** (User runs, AI confirms):
  ```bash
  git remote set-url origin ssh://forgejo@git.aset.love:24212/yi/nixos.git
  git fetch origin
  ```
- [ ] **4.2 Apply Code Changes** (AI):
  - `modules/desktop/web-apps.nix`: app URLs reference `allAddresses.baseDomain` (Decision 2).
- [ ] **4.3 Update User Dotfiles** (AI):
  - `users/assets/dotfiles/ssh/config`: change `cloudflare.fufu.land` to `cloudflare.aset.love` in **both** Host blocks (3 occurrences).
  - `users/assets/dotfiles/zsh/aliases.zsh`: delete the `ffsh` alias line (both `fufu.land` references go with it).
- [ ] **4.4 Deploy Desktop Clients** (User runs, AI waits for confirmation):
  ```bash
  deploy .#yitaishi
  deploy .#yixiaoqing
  # yichuang (WSL): rebuild locally inside WSL
  ```
- [ ] **4.5 Verify Client Operations** (User / AI):
  - Test SSH fallback: `ssh cloudflare.aset.love`
  - Test Attic binary cache pull on client: `nix path-info --store https://cache.aset.love/yi ...`

### Step 5: Documentation, Plan Retirement & Final Audit

- [ ] **5.1 Update all 23 documents under `docs/src/`** (AI — 105 occurrences):
  - Replace all occurrences of `fufu.land` with `aset.love`.
  - Replace `fufu-service-ca` with `aset-service-ca`.
  - Replace `fufu-client-ca` with `aset-client-ca`.
  - Replace `/CN=Fufu Internal Service CA` with `/CN=Aset Internal Service CA`.
- [ ] **5.2 Update CI Maintenance script** (AI):
  - `ci/auto-maintenance.sh`: update git commit email to `auto-maintenance@aset.love`.
- [ ] **5.3 Retire this plan** (AI): delete `docs/src/plans/aset-love-migration-plan.md` in the same change set that completes the migration.
- [ ] **5.4 Run Zero-Tolerance Audit** (AI):
  ```bash
  rg -i "fufu"
  # Must return exactly 1 match: the intentional legacyDomain literal in modules/addresses.nix (Decision 8)
  ```

## 4. Rollback Strategy

If any failure occurs during staging or cutover:

- **Phase 1 failure**: If ACME issuance fails on `yirukou`, `fufu.land` was untouched; simply inspect Lego logs (`ai-ssh yirukou journalctl -u acme-aset.love.service`).
- **Phase 2/3 rollback**: User runs `deploy .#yirukou --rollback` (or `sudo nixos-rebuild switch --rollback`). Nginx and AdGuard immediately revert to the previous working generation.

## Open questions

None — all resolved during review (Decisions 6–10).
