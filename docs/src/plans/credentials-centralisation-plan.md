# Centralised Credentials: Vaultwarden + Authelia

## Status: DEPLOYED, MIGRATION OPEN — 2026-11-25 13:47 generation runs on `yifuwuqi` and `yirukou`: both apps active with `NRestarts=0`, the gate answers `302`/`401` on every gated vhost, and all secret keys resolved (`sops-install-secrets` active). What is not done: TOTP enrolment (so no login has ever completed), the D6 URL migration — which is a live outage — the vault itself (D7/D8), `yixiaoqing`, and Phases F/G.

## Objective

Two jobs that look like one and are not:

- **Store** — one durable, human-usable, restorable home for every credential a person holds. Vaultwarden.
- **Gate** — one login for the web fleet, enforced *in front of* services. Authelia + nginx `auth_request` on `yirukou`.

Acceptance tests:

1. `client -> gate -> service`: every served `yirukou` location answers only after Authelia verified a session, except named exemptions, each with a reason. Enforced by the `auth-gate` contract.
1. No service keeps a login of its own where the app can drop it. Authelia is the only human login and Vaultwarden the only human credential store. Where an app cannot drop its login, that is a named exception, never an accident.

Test 1 holds at the edge. Test 2 holds for the services that drop logins, but the store side of the objective — Vaultwarden actually holding credentials — has not started.

## Current state (deployed and verified, 2026-11-25)

- **Gate**: `yirukou`'s built `nginx.conf` carries 21 gated server blocks, 22 `auth_request` lines, 43 `authelia-check` references and 22 `Remote-User` sets. Probes from `yifuwuqi`: `grafana` → `302 https://authelia.aset.love/?rd=…`, `forgejo` → `302`, `attic` → `200` (exempt), `authelia` → `200`, `vaultwarden` → `200` (exempt).
- **Login**: Authelia's journal shows 1FA accepted for `yi` and then every request 401s with `requires 2FA`. No `secondfactor` line exists and `/var/lib/authelia/notification.txt` was never read, so TOTP is not enrolled: the session never leaves first-factor state.
- **Store**: `vaultwarden` active, Rocket bound to `127.0.0.1:24150`; the journal's only warning is the accepted plain-`ADMIN_TOKEN` one. Zero `identity/connect/token` calls — no account, no item, no attachment.
- **CI**: `forgejo-runner` tasks 1115–1118 cloned `http://127.0.0.1:24200`, so the checkout is off the gate.
- **Backups**: `postgresqlBackup-vaultwarden` / `-authelia` / `backup-vaultwarden-data` timers are installed on the `01:30` slot and have never fired (`LastTriggerUSec` empty).
- **Hosts**: `yitaishi` runs the new generation (substituter `attic.aset.love/yi`, SSH alias `forgejo.aset.love`). `yixiaoqing` times out on the tailnet and still runs the pre-rename generation.

## Live breakage and stale names (fix list)

- **Seerr is degraded by the gate.** `seerr` on `yifuwuqi` polls `https://radarr.aset.love/api/v3/queue|command` and `https://sonarr.aset.love/api/v3/...` with its stored server URLs, every minute, and gets `401` — 866 anonymous 401s since deploy. Its journal says it plainly: `[Download Tracker]: Unable to get queue from Radarr server: yifuwuqi-radar`, `[Jellyfin Sync]: Sync interrupted`. Fix: repoint every Seerr application server (Radarr `24878`, Sonarr `24989`, Jellyfin `24096`) to `127.0.0.1` and restart it.
- **Prowlarr indexers in the \*arr apps point at the gate.** `radarr`/`sonarr` fetch `https://prowlarr.aset.love/1|4|6/api?t=caps&apikey=…` from `10.42.0.2` and get `401`. Fix: each indexer URL becomes `http://127.0.0.1:24696/<id>/`.
- **Other mutable app URLs will do the same**: Prowlarr's application and Torznab entries, Bazarr's Sonarr/Radarr, the \*arr qBittorrent download clients (`127.0.0.1:24080`), per [arr-stack.md](../services/arr-stack.md#port-remap-mutable-dbs).
- **Legacy names still in clients**: the authz log shows `cache.aset.love` (205 narinfo fetches), `agent.aset.love` (89), `home.aset.love`, `homepage.aset.love/*`. None is in the tree (`rg` finds no `cache.aset.love`), so the consumers are unmanaged clients or the undeployed `yixiaoqing`/`yichuang`. A substituter still pointing at `cache.aset.love` cannot fetch.

## Decisions still in force

- **Vaultwarden is the human store, SOPS the machine store.** Machine-facing keys stay in sops; human-only passwords move to the vault (Phase F). The Vaultwarden master password needs an offline record; it cannot live in the vault it unlocks.
- **Named exemptions, each with a reason in code.** `attic` (Attic tokens, cannot follow a redirect), `vaultwarden` (Bitwarden clients call the identity and sync APIs directly; master-password login is stronger than the gate), `jellyfin` and `pinepods` (TV/mobile/podcast clients cannot complete a browser login), `authelia` (the portal), plus `dns.aset.love/dns-query` as a machine protocol. The `auth-gate` contract restates the same list as policy.
- **Per-service disposition, remaining rows**: Forgejo keeps its own login behind the gate — header auth is rejected because any local account on `yifuwuqi` could send `Remote-User: yi` to loopback and have CI run that code as `nix-builder` (Phase G replaces it with OIDC). Seerr keeps its own login (no OIDC, no header login). Cockpit keeps PAM (the OS password is `passwords/yi`). AdGuard Home keeps its first-run admin account. Vaultwarden keeps `/admin`'s `ADMIN_TOKEN` (a disabled token would let any local account administer the vault). Attic keeps tokens.
- **Dropped logins stay dropped**: Grafana (`auth.proxy` on `Remote-User`, org `Admin`), the five \*arr apps and Bazarr (`External` / `auth.type = null`), slskd (`web.authentication.disabled`; `services/slskd/web_password` is dead and still in the encrypted payload).
- **HTTPS git remotes do not work from non-browser clients.** `origin` is `ssh://forgejo@forgejo.aset.love:24212/…`; CI and auto-maintenance use loopback `127.0.0.1:24200`.

## Phases

### Phase C — Deploy (User)

- [x] (User) C1 `yirukou`, then `yifuwuqi`. Done 2026-11-25 13:47.
- [ ] (User) C2 `yitaishi` is done; `yixiaoqing` still runs the pre-rename generation and times out on the tailnet (`100.69.0.3:24212`). Deploy it when reachable — its working tree also carries the fido2/DMS removal.

### Phase D — Runtime verification

- [x] (AI) D1 Services active on both hosts, no startup errors. Evidence in Current state.

- [ ] (User) D2 Gate proof from a LAN browser (my probes ran on `yifuwuqi`, which is inside the mesh):

  ```bash
  curl -sI https://grafana.aset.love/ | sed -n '1p;/^location/Ip'      # 302 -> authelia, rd encoded
  curl -sI https://attic.aset.love/yi/nix-cache-info | head -1          # 200 (exempt)
  ```

- [ ] (User) D3 Finish the login at `https://authelia.aset.love`: password from sops, then **TOTP enrolment**. The first-factor session exists but never reached the second. As root on `yifuwuqi`, `cat /var/lib/authelia/notification.txt` supplies the confirmation code. Then check in a browser: Grafana shows `yi` as Admin; the \*arr UIs, Bazarr and slskd open with no prompt; OpenCode opens with no password prompt; Forgejo and Seerr show their own login.

- [ ] (User) D4 Fail closed: `systemctl stop authelia` on `yifuwuqi` → `curl -sI https://grafana.aset.love/` is `500` while Attic stays `200`; then `systemctl start authelia`.

- [x] (AI) D5 CI clones over loopback (`forgejo-runner` task log). Auto-maintenance's own fetch/push still needs one scheduled run to appear in the log.

- [ ] (User) D6 Repoint every mutable app URL to loopback — the live-breakage list above. Seerr and the Prowlarr indexers in Radarr/Sonarr are already failing; until they are fixed, download tracking, Jellyfin sync and indexer searches stay dead.

- [ ] (User) D7 Vault: open `https://vaultwarden.aset.love/admin` with `sops decrypt --extract '["tokens"]["vaultwarden-admin"]' secrets/secrets.yaml` (as root), invite `yi`, register, and save one item with an attachment.

- [ ] (User) D8 Restore drill, now that D7 gives the backup something to hold: `systemctl start postgresqlBackup-vaultwarden postgresqlBackup-authelia backup-vaultwarden-data`, restore the dump into a scratch database and the archive into a scratch directory, point a scratch Vaultwarden at both, read the attachment back.

### Phase E — Manual renames (User)

- [x] (User) E1 `origin` is `ssh://forgejo@forgejo.aset.love:24212/yi/nixos.git` on this checkout.
- [ ] (User) E2 Find and update whatever still resolves `cache.aset.love`, `agent.aset.love`, `home.aset.love`: bookmarks, Bitwarden item URIs, substituter configs. `cache.aset.love` matters most — narinfo fetches are failing.

### Phase F — Migration SOPS → Vaultwarden (User, after D7)

- [ ] (User) F1 `passwords/workd` (human-only, no consumer left in the tree) and `passwords/nextcloud` (Nextcloud is commented out of `yifuwuqi`): create vault items, then `sops unset secrets/secrets.yaml '["passwords"]["workd"]'` (likewise `nextcloud`) and `nix run .#secrets`.
- [ ] (User) F2 `services/slskd/web_password` is dead since C1: `sops unset secrets/secrets.yaml '["services"]["slskd"]["web_password"]' && nix run .#secrets`.
- [ ] (User) F3 Dual-use keys stay authoritative in sops, and the vault gets a Login item saying so: `samba/credentials/yi`, `services/slskd/{username,password}`, `tokens/deepseek`. `passwords/opencode` is machine-only and needs no item.
- [ ] (User) F4 Vault items for the logins that remain (Decisions): Forgejo, Seerr, Jellyfin, Pinepods, AdGuard, and the OS password behind Cockpit. A reset comes first where the password is unknown (CLI/sqlite).

### Phase G — Follow-ups (AI)

- [ ] (AI) G1 Authelia OIDC for Forgejo, then disable Forgejo's internal sign-in. That removes Forgejo's password without header trust. Pinepods (`OIDC_*` env, standard login disabled) can follow on the same provider.

## Rollout order

1. D3 first: nothing else can be judged until a session actually reaches second factor.
1. D6 in the same sitting — it is an outage, not a hardening step.
1. D2, D4, then D7 → D8.
1. E2, F, then the C2 remainder.
1. G after one deploy cycle.

## Open questions

- **Session cookie reaches exempt backends.** `authelia_session` is scoped to `aset.love`, so Jellyfin, Pinepods, Attic and Vaultwarden receive it. A compromised exempt backend could replay it against gated services, including OpenCode, which the ingress authenticates. Stripping it at the edge needs a `map` over `$http_cookie` and a runtime test.
- **Loopback is trusted on `yifuwuqi`.** Any local process can drive the backends without a login (\*arr, Bazarr, slskd, qBittorrent, SillyTavern, Homepage, SearXNG) and can claim any Grafana user. Containers reach SearXNG (read-only, gated at the edge) and, through gluetun's shared namespace only, an unauthenticated Lidarr.
- **SearXNG stays reachable from every container subnet.** Firecrawl has no fixed address, so narrowing that rule needs the gluetun-style fixed network. Accepted: the endpoint is read-only and the browser path is gated.
- **Tailnet listeners bypass the gate.** `yitaishi`'s `sd-cpp` (`11437`) and `llama-cpp` (`11436`) answer every tailnet peer.
- **Each gated request costs a second mTLS connection** (the subrequest); there is no upstream keepalive on `yirukou` yet.
- **TOTP enrolment needs root** to read the notifier file. SMTP would remove that step, and it is also the reason D3 cannot be finished by a browser alone.
- **Pinepods/Firecrawl hardcoded `postgres`/`pinepods` passwords** ([pinepods.nix](../../../modules/services/pinepods.nix), [firecrawl.nix](../../../modules/services/firecrawl.nix)) are store-visible placeholders on internal-only networks; a separate pass.
