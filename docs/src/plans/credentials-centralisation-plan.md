# Centralised Credentials: Vaultwarden + Authelia

## Status: DRAFT — not started; nothing blocks it

## Objective

One place to *store* every credential (self-hosted, backed up, restorable) and one credential to *use* the web fleet (forward-auth at the ingress), so a forgotten app password stops being a recovery project.

## Current State (repository-verified 2026-11-23)

- **SOPS holds machines, not people.** `secrets/secrets.yaml` is encrypted to the 4 host age keys ([keys.nix](../../../secrets/keys.nix)), identity derived from each host's SSH host key ([sops.nix](../../../secrets/sops.nix)). Root-only. Only 4 human passwords exist in the schema and **3 are dead**: `passwords/yi`, `passwords/workd` (zero `.nix` consumers) and `passwords/nextcloud` (module commented out at [services.nix](../../../hosts/yifuwuqi/services.nix)). Only `passwords/opencode` is wired ([opencode.nix](../../../modules/services/opencode.nix)).
- **Every app password is mutable DB state with no declarative path.** Forgejo admin via CLI ([bootstrap-runbook.md](../hardware/bootstrap-runbook.md)), Jellyfin first-run wizard, \*arr/Readarr/Prowlarr `AuthenticationMethod` + Users table, Pinepods first admin. Losing one means a sqlite/schema reset, not a lookup.
- **Some services have no auth at all**, so there is nothing to lose and nothing to look up: Grafana anonymous Admin ([grafana.nix](../../../modules/services/monitoring/grafana.nix)), AdGuard (`mutableSettings = false`, no `users:` block, [adguardhome.nix](../../../modules/services/adguardhome.nix)), qBittorrent (`WebUI\LocalHostAuth=false` + `AuthSubnetWhitelist=127.0.0.1`, [qbittorrent-vpn.nix](../../../modules/services/qbittorrent-vpn.nix) — the ingress proxies *from* `127.0.0.1`, so the whitelist is fully bypassed), SillyTavern (`basicAuthMode = false`), Homepage, SearXNG, Docs, Firecrawl.
- **The only gate is network position.** `mkLocalVhosts` and `mkRemoteVhosts` admit by LAN CIDR + mTLS peer certificate ([proxy-vhosts.nix](../../../modules/services/proxy-vhosts.nix)), never by identity. No `auth_basic`, no `auth_request`, no `forward_auth` anywhere in the tree. The `proxy-allowlist` contract ([checks.nix](../../../nix/checks.nix)) pins that allow/deny sequence and only inspects lines beginning `allow `/`deny `, so an `auth_request` directive can be added without tripping it.
- **`yi` has no persisted password.** `hashedPasswordFile` is set only for `root`, only on `yitaishi`/`yixiaoqing` ([users.nix](../../../users/users.nix)); `mutableUsers = true`. yirukou mounts a tmpfs `/` and its persistence list ([impermanence-yirukou-plan.md](impermanence-yirukou-plan.md)) contains no `/etc/shadow`. Cockpit/PAM login as `yi` on yirukou therefore cannot survive a reboot — by construction, not by accident.
- **yifuwuqi has no impermanence.** [hardware.nix](../../../hosts/yifuwuqi/hardware.nix) declares only `/` and `/boot`; `/persist` there is a plain directory on root ext4 (that is where postgres lives, [hosts.nix](../../../modules/addresses/hosts.nix)). New yifuwuqi state needs no persistence work.
- **No vault, no IdP.** `vaultwarden`, `authelia`, `lldap`, `kanidm`, `oauth2-proxy` appear nowhere outside nixpkgs. [web-apps.nix](../../../modules/desktop/web-apps.nix) bookmarks the **cloud** `vault.bitwarden.com`, so a store is in use but the fleet owns no copy of it and has no backup of it. No backup tooling exists in-tree at all.
- **nginx supports forward-auth**: nixpkgs' generic build passes `--with-http_auth_request_module` (`/etc/nix/inputs/nixpkgs/pkgs/servers/http/nginx/generic.nix`).
- **Plans need no `SUMMARY.md` entry**: the docs service appends `src/plans/*.md` at serve time ([hosted-services.md](../services/hosted-services.md)).

## Decisions

1. **Vaultwarden, not SOPS, is the human store of record.** SOPS stays machine-facing (tokens, keys, service wiring); humans get a real client with autofill, revisions and 2FA. SOPS holds exactly one new secret for it: the admin token.
1. **Postgres, not sqlite.** yifuwuqi already runs socket-only Postgres driven by `pgDatabases` ([hosts.nix](../../../modules/addresses/hosts.nix), [postgresql.nix](../../../modules/services/postgresql.nix)). Add `vaultwarden = "vaultwarden"` to that map — one source of truth, and `ensureDBOwnership` creates the role. Do **not** set `services.vaultwarden.configurePostgres`; that starts a second server.
1. **Backups land outside the data dir.** The nixpkgs module asserts `backupDir` is not under `dataDir`; Vaultwarden's bundled `backup.sh` is sqlite-bound, so its timer is not a backup for choice 2 — a `pg_dump` unit is required (Phase 2).
1. **Authelia as the single forward-auth gate**, not per-app auth. The \*arr family has no native OIDC at all, and qBittorrent's loopback whitelist makes the proxy the *only* possible gate. One deployment covers the whole tail of apps; native OIDC is then added per-app where it exists (Grafana, Forgejo) as a refinement, not a prerequisite.
1. **Forward-auth applies to human UIs only.** Machine paths (the default `_` vhost, `/loki/`, exporter locations) stay certificate-only. Loopback consumers are unaffected by construction: Prowlarr↔\*arr, recyclarr, soularr and the arr↔qBittorrent links all talk over `127.0.0.1`, never through the ingress.
1. **Jellyfin is exempt from forward-auth.** Native Jellyfin clients (TV, mobile) cannot complete a browser login redirect. It keeps its own user database; Vaultwarden stores the password for it.
1. **`yi` gets a `hashedPasswordFile`, not a persisted `/etc/shadow`.** The file is re-applied at activation, so impermanence stops mattering on yirukou, and the same declaration covers the persistent yifuwuqi. Accepted cost: a `passwd yi` change is overwritten at the next activation — so the SOPS value is the truth.

## Phases

### Phase 1 — Vaultwarden (the recovery store)

- [addresses/hosts.nix](../../../modules/addresses/hosts.nix): add `pgDatabases.vaultwarden`, plus a `services.vaultwarden` registry entry (`name`, `group = "Infrastructure"`, `domain = "vault.${baseDomain}"`, a free 24xxx port).
- `modules/services/vaultwarden.nix`: `dbBackend = "postgresql"`, `DATABASE_URL` on the socket dir, `ROCKET_ADDRESS = "127.0.0.1"`, `ROCKET_PORT` from the registry, `DOMAIN`, `SIGNUPS_ALLOWED = false`, `backupDir = "/var/backup/vaultwarden"`. Admin token via `sops.templates` → `environmentFile` (**escape `$` as `$$`** — systemd expands `$` in `EnvironmentFile` entries and an argon2 hash is full of them).
- [proxy-vhosts.nix](../../../modules/services/proxy-vhosts.nix): `vaultwarden = { bodySize = "512M"; }` in `proxiedServices`.
- [secrets/.secrets.example.yaml](../../../secrets/.secrets.example.yaml) + [secrets.md](../services/secrets.md): `tokens/vaultwarden-admin` recipe.
- Regenerate `docs/src/generated/services.md` (`nix build .#docs-generated`) and add a `hosted-services.md` §2 entry — the `docs-registry-sync` check fails otherwise.

### Phase 2 — Backups that restore

- `pg_dump` unit + timer to `/var/backup/vaultwarden/`, `LoadCredential` from the Postgres role — a vault without a tested restore is theatre.
- Acceptance: restore into a scratch database and log in. Recorded before Phase 3 begins.

### Phase 3 — Authelia (one credential for the fleet)

- `pgDatabases.authelia`, a registry entry (`auth.${baseDomain}`), `modules/services/authelia.nix` with `services.authelia.instances.main`: `default_2fa_method = "totp"`, `server.address = "tcp://127.0.0.1:<port>"`, file authentication backend (users database rendered as a `sops.template`), and `secrets.{jwtSecretFile,storageEncryptionKeyFile,sessionSecretFile}` pointing at `sops.secrets` paths.
- [proxy-vhosts.nix](../../../modules/services/proxy-vhosts.nix): a per-service `auth = true` flag in `proxiedServices` adding `auth_request` plus the 401→`auth.${baseDomain}` redirect to `mkLocalVhosts`, and the matching internal `/authelia/` location. The protected set stays one declaration in the same table.
- Exempt from the start: `jellyfin` (Decision 6), the `_` default vhost, `/loki/`, all exporter locations.
- Flip services in small batches, verifying browser login and one native client each. Start with the three that have no auth at all today — Grafana, AdGuard, qBittorrent — because there forward-auth *adds* security rather than only convenience.

### Phase 4 — Repair the password gap

- [users.nix](../../../users/users.nix): `yi` (and `workd`) get `hashedPasswordFile = config.sops.secrets."passwords/yi".path`, consumed for real.
- Delete `passwords/nextcloud` until the Nextcloud module is re-enabled.
- Verify on yirukou across a reboot: Cockpit login as `yi` works after the tmpfs wipe.

## Rollout Order

1. Phase 1 + 2 on yifuwuqi; populate the vault by hand from the running services. **This is the step that answers "I lost my password"** — and for the \*arr/Jellyfin/Forgejo entries it is a *reset* first (CLI/sqlite), then store.
1. Phase 4 (independent, tiny, fixes a standing bug).
1. Phase 3 on Grafana/AdGuard/qBittorrent, then the remaining human UIs.
1. Phase 3 refinement: native OIDC for Grafana (`auth.generic_oauth`) and Forgejo, retiring their forward-auth entries.

## Open Questions

- \**Where do *arr/Jellyfin passwords actually come from now?** Unrecoverable by design — Phase 1 must include a reset pass, so scope it as such rather than assuming a migration.
- **Should Authelia users come from a file backend or lldap?** File is one less service; lldap becomes worth it only at 3+ real users.
- **Does AdGuard's admin password move into SOPS?** `mutableSettings = false` means the users block is declarative, so it *can* — but the sops-template-as-config path for `adguardhome` needs verifying before promising it.
- **Grafana anonymous Admin**: should forward-auth be the fix, or does anonymous Admin get turned off now that an IdP is coming? Leaving both means the auth layer is decorative.
- **Pinepods/Firecrawl hardcoded `postgres`/`pinepods` passwords** ([pinepods.nix](../../../modules/services/pinepods.nix), [firecrawl.nix](../../../modules/services/firecrawl.nix)) are hardcoded store-visible placeholders. In scope here, or a separate pass?
