# Migration Plan: fufu to aset (Zero-Downtime Domain & Brand Migration)

## Status: PROPOSED — waiting for user approval

## Objective

Migrate the primary homelab domain from `fufu.land` to `aset.love`, eradicating all instances of `fufu` across the repository (code, configurations, dotfiles, scripts, dashboards, and documentation) with **virtually zero service downtime**, **zero data loss**, and **zero git history rewrites**.

______________________________________________________________________

## 1. Zero-Downtime Architecture & Strategy

A naive migration (switching all virtual hosts and ACME cert names in one commit) causes a major outage: if Nginx attempts to load an ACME certificate that Lego has not yet generated, Nginx fails to start or reload, immediately taking down all 22+ reverse-proxied services.

To ensure **zero downtime**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 0: External Setup (Cloudflare Dashboard & Zero Trust)            │
│ • Cloudflare API Token: Ensure zone scope includes aset.love           │
│ • Cloudflare Tunnel: Add cloudflare.aset.love -> SSH on same tunnel    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 1: Gateway Staging (Dual Certificate & Dual DNS on yirukou)      │
│ • yirukou requests security.acme.certs."aset.love" via DNS-01          │
│ • fufu.land remains 100% active and serving traffic                    │
│ • AdGuard Home resolves BOTH *.fufu.land and *.aset.love -> 10.42.0.1  │
│ ➔ DOWNTIME: 0 seconds                                                  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 2: Core Server Cutover (yifuwuqi)                                │
│ • Update modules/addresses.nix (baseDomain = "aset.love")              │
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
│ • Run automated audit: rg -i "fufu" -> 0 matches                       │
│ ➔ DOWNTIME: 0 seconds                                                  │
└────────────────────────────────────────────────────────────────────────┘
```

______________________________________________________________________

## 2. Global Scope & File Inventory

A global case-insensitive search (`rg -i "fufu"`) identified 126 instances across 38 files. All will be migrated to `aset` (preserving git commit history):

1. **Central Domain Registry (`modules/addresses.nix`)**:
   - 26 occurrences: refactored with `baseDomain = "aset.love"`.
1. **Reverse Proxy & ACME (`modules/services/nginx-proxy.nix`, `proxy-vhosts.nix`)**:
   - 15 occurrences: `admin@aset.love`, `certs."aset.love"`, `useACMEHost = "aset.love"`, static vhosts `aset.love`, `adguard.aset.love`, `dns.aset.love`, `goaccess.aset.love`.
1. **Internal Edge DNS (`modules/services/adguardhome.nix`)**:
   - 8 occurrences: rewrites `*.aset.love`, `aset.love`, `smb.aset.love`, `ssh.aset.love`, server name `dns.aset.love`, TLS path `/var/lib/acme/aset.love/`.
1. **Standalone Modules & Dashboards**:
   - `modules/services/homepage.nix`: proxy domains and search widget.
   - `modules/services/searxng.nix`: `base_url` dynamic reference.
   - `modules/services/webdav.nix`: `webdav.aset.love`, `useACMEHost = "aset.love"`.
   - `hosts/yirukou/goaccess.nix`: `--ws-url=wss://goaccess.aset.love/ws`.
   - `modules/desktop/web-apps.nix`: `git.aset.love`, `grafana.aset.love`.
   - `modules/services/monitoring/dashboards/vendor/adguard.json`: drilldown links `https://adguard.aset.love/#logs...`.
   - `modules/services/ai/sillytavern.nix`: comment `companion.aset.love`.
   - `modules/services/forgejo.nix`: comment `git.aset.love`.
1. **Dotfiles, Scripts & Git Remote**:
   - `users/assets/dotfiles/ssh/config`: `cloudflare.aset.love`.
   - `users/assets/dotfiles/zsh/aliases.zsh`: `alias assh="ssh ssh.aset.love || ssh cloudflare.aset.love"`.
   - `ci/auto-maintenance.sh`: `user.email "auto-maintenance@aset.love"`.
   - Local working repository git remote: `origin ssh://forgejo@git.aset.love:24212/yi/nixos.git`.
1. **Documentation & Plans (`docs/`)**:
   - 65+ occurrences across 24 documents, including `fufu-service-ca` $\\to$ `aset-service-ca`, `/CN=Fufu Internal Service CA` $\\to$ `/CN=Aset Internal Service CA`, and `fufu-client-ca` $\\to$ `aset-client-ca`.

______________________________________________________________________

## 3. Rollout Order & Step-by-Step Instructions

### Step 0: Manual External Prerequisites (Cloudflare Dashboard)

Both domains are registered with Cloudflare Registrar. `aset.love` is automatically created as an active zone managed by Cloudflare nameservers. Perform the following three manual configurations:

#### 0.1 Cloudflare API Token Scope

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com) $\\to$ Top right profile icon $\\to$ **My Profile** $\\to$ **API Tokens**.
1. Find the API token used for ACME (`cloudflare_api_token`). Click **Edit**:
   - **Option A (Recommended — Zero Secret Churn)**: Under **Zone Resources**, change the scope from `Specific zone: fufu.land` to **Include $\\to$ All zones from an account $\\to$ [Your Account]** (or add `aset.love` to the list). Click **Continue to summary** $\\to$ **Update Token**.
     - *Result*: No SOPS secret changes or re-encryption required!
   - **Option B (Separate Token)**: If creating a new token, set Permissions: `Zone:DNS:Edit` on `Zone:aset.love`.
     - *SOPS Recipe*: On `yifuwuqi`, run `su -`, then `cd /home/yi/the.files/nixos && sops secrets/secrets.yaml`. Update `cloudflare_api_token: | CLOUDFLARE_DNS_API_TOKEN=<new-token>`, save, and exit.

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

______________________________________________________________________

### Step 1: Gateway Staging (`yirukou`) — Zero Downtime

We provision the wildcard `aset.love` certificate and add dual DNS rewrites without altering any active `fufu.land` service vhosts.

1. **Apply Staging Diff to `modules/services/nginx-proxy.nix`**:
   - Add `certs."aset.love"` alongside `certs."fufu.land"`.
1. **Apply Staging Diff to `modules/services/adguardhome.nix`**:
   - Add rewrites for `*.aset.love`, `aset.love`, `smb.aset.love`, `ssh.aset.love` alongside existing `fufu.land` rewrites.
1. **Verify evaluation**:
   ```bash
   nix eval .#nixosConfigurations.yirukou.config.system.build.toplevel.drvPath
   ```
1. **Deploy to Gateway (`yirukou`)**:
   ```bash
   # From your deployment runner or directly on yirukou:
   # (Option A via deploy-rs):
   deploy .#yirukou
   # (Option B via SSH rebuild):
   # sudo nixos-rebuild switch --flake .#yirukou
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

______________________________________________________________________

### Step 2: Core Server Cutover (`yifuwuqi`)

Now that the gateway can resolve and terminate `aset.love`, update `yifuwuqi`'s service definitions.

1. **Apply Code Changes**:
   - `modules/addresses.nix`: Set `baseDomain = "aset.love";`.
   - `modules/services/searxng.nix`, `homepage.nix`, `webdav.nix`, `adguard.json`: update domain references.
1. **Verify evaluation**:
   ```bash
   nix eval .#nixosConfigurations.yifuwuqi.config.system.build.toplevel.drvPath
   ```
1. **Deploy to Core Server (`yifuwuqi`)**:
   ```bash
   # Deploy yifuwuqi
   deploy .#yifuwuqi
   # Or locally on yifuwuqi:
   # sudo nixos-rebuild switch --flake .#yifuwuqi
   ```
1. **Verify Backend Health**:
   ```bash
   systemctl is-active postgresql forgejo atticd grafana nginx
   ```

______________________________________________________________________

### Step 3: Gateway Cutover (`yirukou`) & Total Purge of `fufu` in Configs

With the backend ready, switch Nginx reverse proxy vhosts and AdGuard Home TLS to `aset.love`, and purge all legacy `fufu.land` vhosts.

1. **Apply Code Changes**:
   - `modules/services/proxy-vhosts.nix`: `useACMEHost = "aset.love";`.
   - `modules/services/nginx-proxy.nix`: remove `certs."fufu.land"`, update static vhosts to `aset.love`.
   - `modules/services/adguardhome.nix`: remove legacy `fufu.land` rewrites; point TLS to `/var/lib/acme/aset.love/`.
   - `hosts/yirukou/goaccess.nix`: update WebSocket URL to `wss://goaccess.aset.love/ws`.
1. **Verify evaluation**:
   ```bash
   nix eval .#nixosConfigurations.yirukou.config.system.build.toplevel.drvPath
   ```
1. **Deploy to Gateway (`yirukou`)**:
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

______________________________________________________________________

### Step 4: Client & Desktop Fleet Rollout

1. **Update Local Git Remote**:
   ```bash
   git remote set-url origin ssh://forgejo@git.aset.love:24212/yi/nixos.git
   git fetch origin
   ```
1. **Update User Dotfiles**:
   - `users/assets/dotfiles/ssh/config`: change `Host cloudflare.fufu.land` to `cloudflare.aset.love`.
   - `users/assets/dotfiles/zsh/aliases.zsh`: change `alias ffsh` to `alias assh="ssh ssh.aset.love || ssh cloudflare.aset.love"`.
1. **Deploy Desktop Clients**:
   ```bash
   deploy .#yitaishi
   deploy .#yixiaoqing
   # yichuang (WSL): rebuild locally inside WSL
   ```
1. **Verify Client Operations**:
   - Test SSH fallback: `ssh cloudflare.aset.love`
   - Test Attic binary cache pull on client: `nix path-info --store https://cache.aset.love/yi ...`

______________________________________________________________________

### Step 5: Documentation & Final Audit

1. **Update all 24 documents under `docs/src/`**:
   - Replace all occurrences of `fufu.land` with `aset.love`.
   - Replace `fufu-service-ca` with `aset-service-ca`.
   - Replace `fufu-client-ca` with `aset-client-ca`.
   - Replace `/CN=Fufu Internal Service CA` with `/CN=Aset Internal Service CA`.
1. **Update CI Maintenance script**:
   - `ci/auto-maintenance.sh`: update git commit email to `auto-maintenance@aset.love`.
1. **Run Zero-Tolerance Audit**:
   ```bash
   rg -i "fufu"
   # Must return 0 matches across the working tree!
   ```

______________________________________________________________________

## 4. Rollback Strategy

If any failure occurs during staging or cutover:

- **Phase 1 failure**: If ACME issuance fails on `yirukou`, `fufu.land` was untouched; simply inspect Lego logs (`journalctl -u acme-aset.love.service`).
- **Phase 2/3 rollback**: Run `deploy .#yirukou --rollback` (or `sudo nixos-rebuild switch --rollback`). Nginx and AdGuard immediately revert to the previous working generation.
