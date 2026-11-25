# Centralised Credentials: Vaultwarden + Authelia

## Status: IN PROGRESS — every (AI) code step is implemented and evaluation-verified in the working tree (2026-11-25, sixth review). Nothing is deployed. B1 is done (both modules are staged). Remaining gates are user-only: B2 (`passwords/yi` value), B3 (three sops keys), then Phase C deploys `yirukou` before `yifuwuqi`.

## Objective

Two jobs that look like one and are not:

- **Store** — one durable, human-usable, restorable home for every credential a person holds. Vaultwarden.
- **Gate** — one login for the web fleet, enforced *in front of* services. Authelia + nginx `auth_request` on `yirukou`.

Target invariant, stated as acceptance tests rather than a slogan:

1. `client -> gate -> service`: every served `yirukou` location answers only after Authelia verified a session, except named exemptions, each with a reason. Enforced by the `auth-gate` contract.
1. No service keeps a login of its own where the app can drop it. Authelia is the only human login and Vaultwarden the only human credential store. Where an app cannot drop its login, that is a named exception (Decision 6), never an accident.

## Evidence Status

- **Repository-verified 2026-11-25**: every path below; `rg` over the tree finds no remaining nickname hostname outside this plan.
- **Settled from pinned sources** (fetch any of them with `nix build --no-link -f /etc/nix/inputs/nixpkgs <pkg>.src`):
  - Authelia 4.39.28 accepts `storage.postgres.address = unix:///<dir>/.s.PGSQL.<port>` (`internal/storage/sql_provider_backend_postgres.go:216-241`), and its validator requires address, username and database but no password (`internal/configuration/validator/storage.go:62-87`). It refuses to start without a notifier (`validator/notifier.go:16-19`), and requires the JWT secret only while password reset is enabled (`validator/identity_validation.go:28`).
  - The AuthRequest endpoint answers a missing session with `401` plus a `Location` carrying the portal URL and an encoded `rd` (`internal/handlers/handler_authz_impl_authrequest.go:38-40`, `handler_authz_util.go:75-83`). Its default authn strategies try `Authorization: Basic` before the cookie (`internal/configuration/schema/server.go:115-125`).
  - Homepage 2.7.0 `ping` reduces the URL to its hostname and sends ICMP (`.next/server/pages/api/ping.js`), so gating never turns a tile red.
  - OpenCode 2.3.0 has no unauthenticated server: without `OPENCODE_PASSWORD` it generates a random one (`packages/cli/src/server-process.ts:91-97`). It accepts the credential only as `base64(opencode:<password>)` in Basic, `?auth_token=`, or its own session cookie (`packages/server/src/middleware/authorization.ts:33-40`).
  - Forgejo 17.0.2 reverse-proxy auth trusts the user header from any client (`services/auth/method/reverseproxy.go:46-52`); `REVERSE_PROXY_TRUSTED_PROXIES` only feeds the client-IP middleware (`routers/common/middleware.go:56-68`).
  - Seerr 3.5.2 has no OIDC or header login anywhere under `server/`. Pinepods reads `OIDC_*` env vars since 0.8.2 (upstream docs).
  - Grafana 13.3.1 `auth.proxy` defaults: `header_property = username`, `auto_sign_up = true` (`conf/defaults.ini:1117-1126`).
  - Vaultwarden 1.37.5 defaults `enable_websocket` to true (`src/config.rs:541`).
  - AdGuard Home 0.107.80 binds its HTTPS server to the `http.address` host (`internal/home/web.go:467`), so `port_https` 3443 is loopback-only and not a gate bypass.
  - The pinned `actions/checkout@11bd719…` has a `github-server-url` input. slskd's key is `web.authentication.disabled` (`config/slskd.example.yml`), and Bazarr treats `auth.type = None` as no login (`bazarr/app/ui.py:56-93`).
- **Must be confirmed at runtime** (Phase D): the login round trip and TOTP enrolment, fail-closed behaviour, the CI clone over loopback, Grafana's header login, and that every mutable inter-service URL is loopback.

## Current State (working tree, 2026-11-25)

- **Names**: every service hostname is its registry key (`forgejo`, `attic`, `homepage`, `searxng`, `opencode`, `sillytavern`, `pinepods`, `sd-cpp`, `adguardhome`). Old nicknames simply stop resolving to a vhost: no redirect shims, since the rename is not this plan's feature. The `vhost-naming` contract rejects nicknames.
- **Store**: [vaultwarden.nix](../../../modules/services/vaultwarden.nix) on `yifuwuqi`, Postgres over the socket with peer auth, `ADMIN_TOKEN` from `tokens/vaultwarden-admin`, signups closed.
- **Gate**: [authelia.nix](../../../modules/services/authelia.nix) on `yifuwuqi` (loopback `24140`, socket peer auth, file backend rendered from sops, `two_factor` everywhere, filesystem notifier). `mkAuthGate` in [proxy-vhosts.nix](../../../modules/services/proxy-vhosts.nix) gates 18 proxied services plus AdGuard, GoAccess and sd-cpp on `yirukou`. The architecture is in [dns-and-proxy.md](../services/dns-and-proxy.md#221-authelia-gate-forward-auth).
- **Backups**: upstream `services.postgresqlBackup` dumps `vaultwarden` and `authelia`, and `backup-vaultwarden-data` archives the data folder, all on the `backups` maintenance slot.
- **Logins dropped**: Grafana, the five \*arr apps, Bazarr and slskd. OpenCode's password is presented by the `yifuwuqi` ingress. CI clones over loopback.
- **OS password**: `yi` gets `hashedPasswordFile` from `passwords/yi` on the four hosts with a sops identity.
- **Deployed reality**: none of the above. The SOPS split, the "lost my password" problem and the zero-auth services described in the 2026-11-24 draft are still live until Phase C.

## Why two services, not one

- **Different capabilities.** Vaultwarden stores arbitrary third-party credentials for a human without root, and restores as data. Authelia gates any HTTP app per request with one session across hostnames, and fails independently of the apps. Neither does the other's job: a gate creates no record of a lost database password, and a vault's client-side protocol (master password + KDF) cannot become a request gate.
- **Different failure domains.** If the vault were the gate, a vault restart would log the fleet out. If the gate stored secrets, the most sensitive database would sit on the request path of every page load.
- **SOPS is neither.** Age identities derive from host keys, files are root-only, and every edit is a rebuild. It stays the machine-facing store.

## Decisions

1. **Vaultwarden is the human store, SOPS the machine store.** This plan adds three sops keys: `tokens/vaultwarden-admin`, `services/authelia/storage-encryption-key`, and `services/authelia/users/yi` (an argon2id digest). `passwords/yi` gets its first consumer (Decision 9).

1. **Postgres via `pgDatabases`, socket peer auth for both apps.** `vaultwarden` and `authelia` are registry databases ([hosts.nix](../../../modules/addresses/hosts.nix)), so `ensureDBOwnership` creates matching roles and no database password exists. `services.vaultwarden.configurePostgres` stays off. It would not start a second server, but it would duplicate `pgDatabases`' ensure entries and hardcode the socket path. Both units `require` `postgresql.target`, which includes the role-creating setup unit.

1. **The gate sits on `yirukou`: one enforcement point, one helper.** yifuwuqi's ingress admits only `CN=yirukou-client`, so every browser request already crossed `yirukou`. `mkAuthGate` returns the location directives and the internal endpoint. `mkRemoteVhosts` uses it for `proxiedServices`, and [nginx-proxy.nix](../../../modules/services/nginx-proxy.nix) for the `yirukou`-local vhosts. The ingress is not gated a second time.

1. **Authelia runs as `authelia`.** The instance is named `""`, so its service account carries the registry role's name and peer auth matches. The `server.address` is loopback.

1. **Named exemptions, each with a reason in code.** A `proxiedServices` entry carries `authExempt = "<reason>"`; the `auth-gate` contract restates the same list as policy.

   - `attic`: Nix substituters and `attic push` use Attic tokens and cannot follow a redirect.
   - `vaultwarden`: Bitwarden clients call the identity and sync APIs directly, and the master-password login is stronger than the gate.
   - `jellyfin`, `pinepods`: TV, mobile and podcast clients cannot complete a browser login (user decision 2026-11-25).
   - `authelia`: the portal itself.
   - `dns.aset.love/dns-query`: a machine protocol.

1. **Per-service login disposition** (target invariant 2):

   | Service                                                                              | Before                | After                                                                                                                                                                                                                                         |
   | ------------------------------------------------------------------------------------ | --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
   | Grafana                                                                              | anonymous Admin       | `auth.proxy` on `Remote-User` from the loopback ingress, auto sign-up as org `Admin`                                                                                                                                                          |
   | Radarr, Sonarr, Lidarr, Readarr, Prowlarr                                            | mutable (unknown)     | `AuthenticationMethod=External`; API keys unchanged                                                                                                                                                                                           |
   | Bazarr                                                                               | mutable (unknown)     | `auth.type = null`                                                                                                                                                                                                                            |
   | slskd                                                                                | `slskd` + password    | `web.authentication.disabled`; `services/slskd/web_password` is removed from the module and the example schema (drop it from the encrypted payload in F2)                                                                                     |
   | OpenCode                                                                             | Basic password, typed | Basic password presented by the ingress (`opencode-ingress-credential`); nobody types it                                                                                                                                                      |
   | AdGuard Home                                                                         | first-run admin login | own login kept (AdGuard stores its own users; first-run setup in the UI), now gated                                                                                                                                                           |
   | qBittorrent, SillyTavern, Homepage, SearXNG, Docs, GoAccess, sd-cpp, torrent-indexer | none                  | none, now gated                                                                                                                                                                                                                               |
   | Forgejo                                                                              | own login             | own login, gated. Header auth is rejected: any local account on `yifuwuqi` could send `Remote-User: yi` to loopback, edit `develop`, and have CI run that code as `nix-builder`, which holds the fleet deploy key. OIDC replaces it (Phase G) |
   | Seerr                                                                                | own login             | own login, gated: it cannot delegate                                                                                                                                                                                                          |
   | Cockpit                                                                              | PAM                   | PAM, gated (user decision 2026-11-25); the OS password is `passwords/yi`                                                                                                                                                                      |
   | Jellyfin, Pinepods                                                                   | own login             | own login, exempt (Decision 5)                                                                                                                                                                                                                |
   | Vaultwarden                                                                          | —                     | master password (the vault itself); `/admin` uses `ADMIN_TOKEN`, kept because a disabled token would let any local account administer the vault                                                                                               |
   | Attic                                                                                | tokens                | tokens (machine)                                                                                                                                                                                                                              |

1. **Forward auth authenticates the request.** A service with no user model stays single-user behind a door. Where an app trusts a header safely (Grafana), the gate sets `Remote-User` from Authelia's response and overwrites any client value.

1. **One cookie domain, Authelia builds the redirect.** `session.cookies` has `domain = aset.love` and `authelia_url = https://authelia.aset.love`. A `401` becomes a `302` to `$upstream_http_location`, the URL Authelia computed with `rd` encoded. The gate never assembles `rd` from `$scheme`/`$host`.

1. **No Redis.** Sessions live in Authelia's memory, so a restart logs everyone out. `session.secret` is validated only under Redis.

1. **`yi` gets `hashedPasswordFile` from `passwords/yi` (`neededForUsers`); `mutableUsers` stays `true`.** It applies only on the four hosts with a sops identity (`yichuang` has none). An existing account keeps its hash (`update-users-groups.pl` writes it only at creation), so the file is a fresh-install net until [impermanence-yirukou-plan.md](impermanence-yirukou-plan.md) makes `yirukou`'s `/etc` ephemeral.

1. **A vhost name is its registry key, permanently.** The `vhost-naming` contract enforces it.

1. **`ADMIN_TOKEN` is a plain random token**, so no PHC `$` quoting reaches `EnvironmentFile=`. Vaultwarden logs a warning about plain tokens; that is accepted.

1. **Forgejo is gated and CI stays off the gate.** All three workflows check out with `github-server-url: http://127.0.0.1:24200`, which also makes `origin` loopback for auto-maintenance's fetch and push. The GitHub runner's `FORGEJO_INTERNAL_URL` is loopback too. HTTPS git remotes stop working from non-browser clients; the SSH remote on `24212` never touches nginx.

1. **Contracts pin the gate, because it fails open in exactly one way.** `proxy-allowlist` exempts `internal;` locations, which only subrequests reach. `auth-gate` requires every other served location to be gated or listed, and every gate's target to be an internal location that proxies to `/api/authz/auth-request` with `Host: authelia.aset.love`. Under any other target the ingress would ask the backend itself, and a single-page app's catch-all `200` would admit every request.

1. **Two factors everywhere; users are read-only.** `access_control.default_policy = two_factor` and `default_2fa_method = totp`. The users file is a sops template, so password reset and change are disabled, which also removes the JWT-secret requirement (`secrets.manual = true`). The filesystem notifier writes the TOTP enrolment code to `/var/lib/authelia/notification.txt`.

1. **The subrequest drops client `Authorization`.** AuthRequest tries Basic before the cookie. A browser still caching OpenCode's old Basic credential would otherwise fail the gate on every request and loop the redirect. The endpoint also sets `recommendedProxySettings = false`, because the recommended include would add a second `Host`, which the ingress rejects.

## Review corrections (fourth pass, against the 2026-11-24 draft)

1. Authelia had no notifier and would not have started (`ValidateNotifier`).
1. Decision 4's TCP lane could never authenticate: `ensureUsers` creates the `authelia` role without a password and nothing set one. It is replaced by socket peer auth, which drops `services/authelia/storage-password`.
1. `services/authelia/jwt-secret` is unnecessary with password reset off. The users-file digest was missing from the key count. Net: three new keys, not four.
1. The hand-built `?rd=$scheme://$host$request_uri` was not URL-encoded; Authelia's own `Location` now drives the `302`.
1. The Homepage `ping` step was moot (ICMP) and is dropped.
1. OpenCode cannot run without a password; the ingress now presents it.
1. Vaultwarden: the "second server" claim was false, and `ENABLE_WEBSOCKET` is already the default (dropped). The missing `requires`/`after` on `postgresql.target` is added.
1. Missed in the draft: the duplicate `Host` header, the Basic-before-cookie strategy, auto-maintenance's `origin`, the GitHub runner's public `FORGEJO_INTERNAL_URL`, and `passwords/yi` on a host without a sops identity.
1. Forgejo header auth, `DISABLE_ADMIN_TOKEN` and per-path gating were considered and rejected: the first two would make every local account on `yifuwuqi` a principal.
1. Backups use the upstream `services.postgresqlBackup` instead of a custom `pg_dump` unit.

## Review corrections (fifth pass, against the staged diff)

1. The `auth-gate` contract checked the subrequest target but not identity propagation. Grafana's `auth.proxy` is its only remaining login, so a gated location that lost `proxy_set_header Remote-User` would authenticate nobody and could not be fixed by logging in. The contract now rejects it (`drops the identity header`).
1. Dropping Lidarr's login made the existing firewall rule material: it admitted every application container subnet to Lidarr's port. The rule now names one caller, gluetun's fixed address, because soularr reaches the host through gluetun's shared namespace; `containers.gluetun.network` (`172.19.0.0/24`, host `.2`) is created in `podman-gluetun`'s `ExecStartPre` the way Cloudflared's is. gluetun joins `isolation.sourceSubnets` so it keeps DNS.
1. The disposition table said AdGuard had no login. It keeps its own first-run admin account; only the gate in front is new.
1. Checked and found sound: `External` really is anonymous (`NoAuthenticationHandler`), `RADARR__AUTH__METHOD` maps to `Radarr:Auth:Method`, Bazarr's `auth.type = null` is legal, slskd's `disabled` key exists, and `Remote-User` does reach Grafana because the ingress forwards request headers by default.

## Review corrections (sixth pass, against the working tree)

1. `opencode-ingress-credential.service` reads `passwords/opencode` directly, but only `opencode.env` carried a `restartUnits`. Rotating the password left nginx presenting the old Basic credential and OpenCode answering `401` until the next rebuild that changed the template. Both units now restart from the same template.
1. B1 was already satisfied (both modules staged), so the plan no longer asks for it.
1. Verified sound and left alone: the gate's `error_page 401` fires only for the `auth_request` result, because `proxy_intercept_errors` is off (checked in the built `nginx.conf`) and a backend's own `401` passes through untouched; `include /run/opencode-ingress-credential/*.conf` tolerates zero matches (`ngx_open_glob` returns `NGX_OK` on `GLOB_NOMATCH` with `test = 1`); the `= /authelia-check` locations set `recommendedProxySettings = false`, so no second `Host` reaches the ingress (the `mkRemoteVhosts` location does include the recommended file, but a duplicate `Host` inside one location is not produced — the include supplies the only `Host` there); Grafana's `auth.proxy` whitelist compares `r.HTTPRequest.RemoteAddr`, which is the ingress's loopback address, and `::1` parses to a `/128`; Vaultwarden's socket `DATABASE_URL` is the shape `configurePostgres` itself sets; Authelia starts without a JWT secret because reset is disabled (`ValidateIdentityValidation`) and without `session.secret` because there is no Redis; the filesystem notifier satisfies `ValidateNotifier`; `access_control.default_policy = two_factor` with no rules is a warning, not an error.

## Phases

### Phase A — Code (AI)

- [x] (AI) A1 Rename: nine registry domains, SearXNG `base_url`, the AdGuard vhost, three stale comments, two vendored dashboard links, prose in `docs/`, and `docs/src/generated/services.md` regenerated.
- [x] (AI) A2 Vaultwarden: registry entry (`24150`), `pgDatabases.vaultwarden`, module, backups, `authExempt`.
- [x] (AI) A3 Authelia: registry entry (`24140`), `pgDatabases.authelia`, module, backup.
- [x] (AI) A4 Gate: `mkAuthGate`, exemption reasons, the `yirukou`-local vhosts.
- [x] (AI) A5 Logins dropped (Decision 6) and the OpenCode ingress credential.
- [x] (AI) A6 CI on loopback (three workflows, `setup-ci-env`).
- [x] (AI) A7 `passwords/yi` → `hashedPasswordFile` on hosts with a sops identity.
- [x] (AI) A8 Contracts `proxy-allowlist` (internal exemption), `auth-gate`, `vhost-naming`.
- [x] (AI) A9 Docs: [hosted-services.md](../services/hosted-services.md), [dns-and-proxy.md](../services/dns-and-proxy.md), [secrets.md](../services/secrets.md) recipes, [arr-stack.md](../services/arr-stack.md), [monitoring.md](../services/monitoring.md), [ci-cd.md](../services/ci-cd.md), host pages.
- [x] (AI) A10 Fifth-pass fixes: the contract pins `Remote-User`, gluetun gets a fixed network so only soularr reaches Lidarr, and the disposition table corrects AdGuard's login.
- [x] (AI) A11 Sixth-pass fixes: the ingress credential restarts when `passwords/opencode` rotates, and the plan records B1 as done.

Gate A evidence is under [Verification](#verification).

### Phase B — Secrets and staging (User)

- [x] (User) B1 Flakes see only tracked files, so both new modules must be staged (a deploy without them fails evaluation). Done: `modules/services/authelia.nix` and `modules/services/vaultwarden.nix` are in the index.

- [ ] (User) B2 Confirm `passwords/yi` exists and is a crypt hash usable by `hashedPasswordFile` (yescrypt `$y$…` or sha512crypt `$6$…`; argon2 is not a libxcrypt format). No `userborn`/`sysusers`, so this is the `setupSecretsForUsers` activation script, and `users.deps` makes a missing or unreadable key fail activation on all four keyed hosts. As root, without printing it:

  ```bash
  su -
  cd /home/yi/the.files/nixos
  sops decrypt --extract '["passwords"]["yi"]' secrets/secrets.yaml | cut -c1-3   # expect $y$ or $6$
  # if missing or another format:
  sops set secrets/secrets.yaml '["passwords"]["yi"]' "$(printf '%s' "$(nix shell nixpkgs#mkpasswd -c mkpasswd -m yescrypt)" | jq -Rs .)"
  ```

- [ ] (User) B3 Add the three new keys and install the payload (as root, in the repo). `--value-stdin` keeps every secret out of the process list, and `jq -Rs .` is what makes the value a JSON string as `sops set` requires — a bare `$argon2id$…` digest would otherwise be parsed as JSON and rejected:

  ```bash
  nix shell nixpkgs#openssl nixpkgs#jq

  openssl rand -base64 48 | jq -Rs . |
    sops set secrets/secrets.yaml '["tokens"]["vaultwarden-admin"]' --value-stdin

  openssl rand -hex 32 | jq -Rs . |
    sops set secrets/secrets.yaml '["services"]["authelia"]["storage-encryption-key"]' --value-stdin

  # prompts twice for the Authelia password, prints "Digest: $argon2id$..."
  nix run nixpkgs#authelia -- crypto hash generate argon2 | sed -n 's/^Digest: //p' | jq -Rs . |
    sops set secrets/secrets.yaml '["services"]["authelia"]["users"]["yi"]' --value-stdin

  nix run .#secrets
  ```

  All three are hard requirements: `decryptSecrets` runs before anything is written, so one absent key fails `sops-install-secrets.service` outright and leaves no `/run/secrets` at all — every unit that `Wants=` it then starts without its credentials.

  The Vaultwarden master password needs an offline record: it cannot live in the vault it unlocks. The Authelia password may go into the vault, which stays reachable without the gate.

### Phase C — Deploy (User)

- [ ] (User) C1 Deploy `yirukou` **before** `yifuwuqi`. In that order the gap only fails closed: gated vhosts answer `500` and renamed ones `404` until `yifuwuqi` lands. The reverse order would serve the \*arr apps, Bazarr and slskd without any login through `yirukou`'s old ungated vhosts. As root, in the repo:

  ```bash
  nix flake check --no-build
  deploy --skip-checks .#yirukou
  deploy --skip-checks .#yifuwuqi
  ```

- [ ] (User) C2 Deploy `yitaishi` and `yixiaoqing` (new substituter name, `forgejo.aset.love` SSH alias, `passwords/yi`).

### Phase D — Runtime verification (AI reads via `ai-ssh`, User drives the browser)

- [ ] (AI) D1 After C1: `ai-ssh yifuwuqi systemctl is-active authelia vaultwarden opencode-ingress-credential nginx postgresql` and `ai-ssh yirukou systemctl is-active nginx`, plus `journalctl -u authelia -u vaultwarden` for startup errors.

- [ ] (User) D2 Gate proof from a LAN client:

  ```bash
  curl -sI https://grafana.aset.love/ | sed -n '1p;/^location/Ip'      # 302 -> https://authelia.aset.love/?rd=...
  curl -sI https://attic.aset.love/yi/nix-cache-info | head -1          # 200 (exempt)
  curl -sI https://forgejo.aset.love/ | sed -n '1p;/^location/Ip'       # 302 -> authelia, i.e. the name serves
  ```

- [ ] (User) D3 First login at `https://authelia.aset.love`: the password from B3, then TOTP enrolment. As root on `yifuwuqi`, `cat /var/lib/authelia/notification.txt` shows the confirmation code. Then check: Grafana shows `yi` as Admin; the \*arr UIs, Bazarr and slskd open without a prompt; OpenCode opens without a password prompt.

- [ ] (User) D4 Fail closed: `systemctl stop authelia` on `yifuwuqi` → `curl -sI https://grafana.aset.love/` is `500` and Attic still `200`; then `systemctl start authelia`.

- [ ] (User) D5 CI: push to `develop`; the checkout step logs `http://127.0.0.1:24200`. The next auto-maintenance run fetches and pushes the bot branch.

- [ ] (User) D6 Mutable app URLs must be loopback, never a gated `*.aset.love`: Prowlarr application and Torznab entries, Seerr's Jellyfin/Radarr/Sonarr servers, Bazarr's Sonarr/Radarr, and the \*arr qBittorrent clients ([arr-stack.md](../services/arr-stack.md#port-remap-mutable-dbs)).

- [ ] (User) D7 Vault: open `https://vaultwarden.aset.love/admin` with the token (`sops decrypt --extract '["tokens"]["vaultwarden-admin"]' secrets/secrets.yaml`, as root), invite `yi`, register, and save one item with an attachment.

- [ ] (User) D8 Restore drill: `systemctl start postgresqlBackup-vaultwarden postgresqlBackup-authelia backup-vaultwarden-data`. Restore `/var/backup/postgresql/vaultwarden.sql.gz` into a scratch database and `/var/backup/vaultwarden/data.tar.gz` into a scratch directory, point a scratch Vaultwarden at both, and read the attachment back.

### Phase E — Manual renames (User)

- [ ] (User) E1 On every checkout: `git remote set-url origin ssh://forgejo@forgejo.aset.love:24212/yi/nixos.git`. The SSH alias for `git.aset.love` disappears with C1/C2.
- [ ] (User) E2 Update bookmarks and Bitwarden item URIs to the registry names.

### Phase F — Migration SOPS → Vaultwarden (User, after D7)

- [ ] (User) F1 `passwords/workd` and `passwords/nextcloud` (human-only): create vault items, then `sops unset secrets/secrets.yaml '["passwords"]["workd"]'` (likewise `nextcloud`) and `nix run .#secrets`.
- [ ] (User) F2 `services/slskd/web_password` is dead after C1 (the module no longer reads it): `sops unset secrets/secrets.yaml '["services"]["slskd"]["web_password"]' && nix run .#secrets`.
- [ ] (User) F3 Dual-use keys stay authoritative in sops, and the vault gets a Login item saying so: `samba/credentials/yi`, `services/slskd/{username,password}`, `tokens/deepseek`. `passwords/opencode` is machine-only now and needs no item.
- [ ] (User) F4 Vault items for the logins that remain (Decision 6): Forgejo, Seerr, Jellyfin, Pinepods, and the OS password behind Cockpit. A reset comes first where the password is unknown (CLI/sqlite).

### Phase G — Follow-ups (AI, after one deploy cycle)

- [ ] (AI) G1 Authelia OIDC for Forgejo, then disable Forgejo's internal sign-in. That removes Forgejo's password without header trust. Pinepods (`OIDC_*` env, standard login disabled) can follow on the same provider.

## Rollout Order

1. Phase B (stage and add secrets; nothing changes on hosts).
1. C1: `yirukou`, then `yifuwuqi`.
1. D1–D8, one gate at a time.
1. E, F, then C2.
1. G after one deploy cycle.

## Verification

Run in this change set, against a mirror of the tracked and non-ignored tree (`git ls-files -co --exclude-standard`), because flakes do not see the two unstaged modules:

- `nix fmt -- --fail-on-change`: 0 files changed (deadnix, nixf-diagnose, statix, nixfmt, mdformat, yamlfmt).
- `nix eval` of `system.build.toplevel.drvPath` succeeds for all five hosts, and of `checks.x86_64-linux.contracts.drvPath` (every contract passes).
- Contract mutation tests. Each mutation fails evaluation with the expected message: removing sd-cpp's gate (`sd-cpp.aset.love// is ungated`), pointing the endpoint `Host` at the backend (`gates through invalid /authelia-check`), dropping `internal;` (`proxy-allowlist failed`), a nickname domain (`yifuwuqi.sillytavern is companion.aset.love`), an unlisted `authExempt` (`grafana.aset.love// is ungated`), `auth_request off` (`gates through invalid off`), and deleting the identity line (`drops the identity header`).
- Built `nginx.conf` for `yirukou` and `yifuwuqi`; the build runs nixpkgs' gixy check. The `yirukou` config has 21 gated server blocks, each with its own internal endpoint, plus 22 `auth_request` lines (GoAccess gates two locations). Attic has no gate, and the ingress's OpenCode location includes `/run/opencode-ingress-credential/*.conf`.
- `authelia validate-config` (4.39.28) passes on the generated `config.yml` with throwaway test values. Its only warning is the intended one: `two_factor` applies to every request.
- Evaluated values: `RADARR__AUTH__METHOD=External`, `PROWLARR__AUTH__METHOD=External`, `DYNACONF_auth__type=@json null`, Grafana `auth.proxy` enabled with `auth.anonymous` absent, `vaultwarden` and `authelia` in `ensureDatabases`. Backup timers sit on the `01:30` slot. `hashedPasswordFile` is set on the keyed hosts and null on `yichuang`. gluetun attaches to `gluetun` with `--ip=172.19.0.2`, and the host firewall admits only that address to Lidarr's port.

Not covered by evaluation: everything in Phase D.

## Open Questions

- **Session cookie reaches exempt backends.** `authelia_session` is scoped to `aset.love`, so Jellyfin, Pinepods, Attic and Vaultwarden receive it. A compromised exempt backend could replay it against gated services, including OpenCode, which the ingress authenticates. Stripping the cookie at the edge needs a `map` over `$http_cookie` and a runtime test.
- **Loopback is trusted on `yifuwuqi`.** Any local process can drive the backends without a login (\*arr, Bazarr, slskd, qBittorrent, SillyTavern, Homepage, SearXNG) and can claim any Grafana user. Containers reach SearXNG (read-only, gated at the edge) and, through gluetun's shared namespace only, an unauthenticated Lidarr; every other container-to-host API is closed.
- **SearXNG stays reachable from every container subnet.** Firecrawl has no fixed address, so narrowing that rule needs the same fixed-network treatment gluetun just received. Accepted for now: the endpoint is read-only and the browser path is gated.
- **Tailnet listeners bypass the gate.** yitaishi's `sd-cpp` (`11437`) and `llama-cpp` (`11436`) answer every tailnet peer. Their consumers are SillyTavern, OpenCode and `yirukou`; narrowing `IPAddressAllow` would close the browser path.
- **Each gated request costs a second mTLS connection** (the subrequest); there is no upstream keepalive on `yirukou` yet.
- **TOTP enrolment needs root** to read the notifier file. SMTP would remove that step.
- **Pinepods/Firecrawl hardcoded `postgres`/`pinepods` passwords** ([pinepods.nix](../../../modules/services/pinepods.nix), [firecrawl.nix](../../../modules/services/firecrawl.nix)) are store-visible placeholders on internal-only networks; a separate pass.
