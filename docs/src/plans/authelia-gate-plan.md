# Authelia Gate: One Login for the Web Fleet

## Status: DEPLOYED, ENROLMENT OPEN — 2026-11-25 13:47 generation runs on `yifuwuqi` and `yirukou`: Authelia active with `NRestarts=0`, the gate answers `302`/`401` on every gated vhost, and all secret keys resolved. What is not done: TOTP enrolment (so no login has ever completed), the D6 URL migration — which is a live outage — `yixiaoqing`, payload hygiene, and Phase G. Vaultwarden was removed from the repo on 2026-11-25 in favour of the hosted Bitwarden account already in use; the running host keeps it until the next `yifuwuqi` switch.

## Objective

One login for the web fleet, enforced *in front of* services: Authelia + nginx
`auth_request` on `yirukou`.

Acceptance tests:

1. `client -> gate -> service`: every served `yirukou` location answers only
   after Authelia verified a session, except named exemptions, each with a
   reason. Enforced by the `auth-gate` contract.
1. No service keeps a login of its own where the app can drop it. Authelia is
   the only human login; where an app cannot drop its login, that is a named
   exception, never an accident.

Test 1 holds at the edge. Test 2 holds for the services that drop logins.

## Scope note: why there is no store half

This plan originally paired the gate with Vaultwarden as a self-hosted human
credential store, and Phase F migrated dead and dual-use keys into it. That
half is gone: a hosted Bitwarden account already covers the human store, so a
second one added a service, a Postgres role, a permanent auth exemption, two
backup artefacts and a restore drill that had never run — for zero content
(no account, no item, no attachment had ever been created).

The load-bearing asymmetry is that Nix can never read the vault: evaluation is
pure and offline, and anything Nix reads lands world-readable in `/nix/store`.
Machine-facing secrets therefore stay in SOPS permanently, whatever their human
readability. With the vault retired, SOPS is the only store, and the rules below
keep it honest.

## Current state (deployed and verified, 2026-11-25)

- **Gate**: `yirukou`'s built `nginx.conf` carries 21 gated server blocks, 22
  `auth_request` lines, 43 `authelia-check` references and 22 `Remote-User`
  sets. Probes from `yifuwuqi`: `grafana` → `302 https://authelia.aset.love/?rd=…`,
  `forgejo` → `302`, `attic` → `200` (exempt), `authelia` → `200`.
- **Login**: Authelia's journal shows 1FA accepted for `yi` and then every
  request 401s with `requires 2FA`. No `secondfactor` line exists and
  `/var/lib/authelia/notification.txt` was never read, so TOTP is not enrolled:
  the session never leaves first-factor state.
- **CI**: `forgejo-runner` tasks 1115–1118 cloned `http://127.0.0.1:24200`, so
  the checkout is off the gate.
- **Backups**: `postgresqlBackup-authelia` is installed on the `01:30` slot and
  has never fired (`LastTriggerUSec` empty).
- **Hosts**: `yitaishi` runs the new generation (substituter
  `attic.aset.love/yi`, SSH alias `forgejo.aset.love`). `yixiaoqing` times out
  on the tailnet and still runs the pre-rename generation.

## Live breakage and stale names (fix list)

- **Seerr is degraded by the gate.** `seerr` on `yifuwuqi` polls
  `https://radarr.aset.love/api/v3/queue|command` and
  `https://sonarr.aset.love/api/v3/...` with its stored server URLs, every
  minute, and gets `401` — 866 anonymous 401s since deploy. Its journal says it
  plainly: `[Download Tracker]: Unable to get queue from Radarr server: yifuwuqi-radar`, `[Jellyfin Sync]: Sync interrupted`. Fix: repoint every Seerr
  application server (Radarr `24878`, Sonarr `24989`, Jellyfin `24096`) to
  `127.0.0.1` and restart it.
- **Prowlarr indexers in the \*arr apps point at the gate.** `radarr`/`sonarr`
  fetch `https://prowlarr.aset.love/1|4|6/api?t=caps&apikey=…` from `10.42.0.2`
  and get `401`. Fix: each indexer URL becomes `http://127.0.0.1:24696/<id>/`.
- **Other mutable app URLs will do the same**: Prowlarr's application and
  Torznab entries, Bazarr's Sonarr/Radarr, the \*arr qBittorrent download
  clients (`127.0.0.1:24080`), per
  [arr-stack.md](../services/arr-stack.md#port-remap-mutable-dbs).
- **Legacy names still in clients**: the authz log shows `cache.aset.love`
  (205 narinfo fetches), `agent.aset.love` (89), `home.aset.love`,
  `homepage.aset.love/*`. None is in the tree (`rg` finds no
  `cache.aset.love`), so the consumers are unmanaged clients or the undeployed
  `yixiaoqing`/`yichuang`. A substituter still pointing at `cache.aset.love`
  cannot fetch.

## Decisions still in force

- **SOPS is the only secret store.** Machine-facing keys live there and nowhere
  else, enforced by the fact that Nix cannot read anything else at eval time. A
  human who needs to know a value records it in the hosted Bitwarden account as
  a pointer to the SOPS path; the SOPS value stays authoritative.
- **Named exemptions, each with a reason in code.** `attic` (Attic tokens,
  cannot follow a redirect), `jellyfin` and `pinepods` (TV/mobile/podcast
  clients cannot complete a browser login), `authelia` (the portal), plus
  `dns.aset.love/dns-query` as a machine protocol. The `auth-gate` contract
  restates the same list as policy.
- **Per-service disposition, remaining rows**: Forgejo keeps its own login
  behind the gate — header auth is rejected because any local account on
  `yifuwuqi` could send `Remote-User: yi` to loopback and have CI run that code
  as `nix-builder` (Phase G replaces it with OIDC). Seerr keeps its own login
  (no OIDC, no header login). Cockpit keeps PAM (the OS password is
  `passwords/yi`). AdGuard Home keeps its first-run admin account. Attic keeps
  tokens.
- **Dropped logins stay dropped**: Grafana (`auth.proxy` on `Remote-User`, org
  `Admin`), the five \*arr apps and Bazarr (`External` / `auth.type = null`),
  slskd (`web.authentication.disabled`).
- **HTTPS git remotes do not work from non-browser clients.** `origin` is
  `ssh://forgejo@forgejo.aset.love:24212/…`; CI and auto-maintenance use
  loopback `127.0.0.1:24200`.

## Phases

### Phase C — Deploy (User)

- [x] (User) C1 `yirukou`, then `yifuwuqi`. Done 2026-11-25 13:47.
- [ ] (User) C2 `yitaishi` is done; `yixiaoqing` still runs the pre-rename
  generation and times out on the tailnet (`100.69.0.3:24212`). Deploy it when
  reachable.

### Phase D — Runtime verification

- [x] (AI) D1 Services active on both hosts, no startup errors. Evidence in
  Current state.

- [ ] (User) D2 Gate proof from a LAN browser (my probes ran on `yifuwuqi`,
  which is inside the mesh):

  ```bash
  curl -sI https://grafana.aset.love/ | sed -n '1p;/^location/Ip'      # 302 -> authelia, rd encoded
  curl -sI https://attic.aset.love/yi/nix-cache-info | head -1          # 200 (exempt)
  ```

- [ ] (User) D3 Finish the login at `https://authelia.aset.love`: password from
  sops, then **TOTP enrolment**. The first-factor session exists but never
  reached the second. As root on `yifuwuqi`, `cat /var/lib/authelia/notification.txt` supplies the confirmation code. Then check
  in a browser: Grafana shows `yi` as Admin; the \*arr UIs, Bazarr and slskd
  open with no prompt; OpenCode opens with no password prompt; Forgejo and Seerr
  show their own login.

- [ ] (User) D4 Fail closed: `systemctl stop authelia` on `yifuwuqi` →
  `curl -sI https://grafana.aset.love/` is `500` while Attic stays `200`; then
  `systemctl start authelia`.

- [x] (AI) D5 CI clones over loopback (`forgejo-runner` task log).
  Auto-maintenance's own fetch/push still needs one scheduled run to appear in
  the log.

- [ ] (User) D6 Repoint every mutable app URL to loopback — the live-breakage
  list above. Seerr and the Prowlarr indexers in Radarr/Sonarr are already
  failing; until they are fixed, download tracking, Jellyfin sync and indexer
  searches stay dead.

### Phase E — Manual renames (User)

- [x] (User) E1 `origin` is `ssh://forgejo@forgejo.aset.love:24212/yi/nixos.git`
  on this checkout.
- [ ] (User) E2 Find and update whatever still resolves `cache.aset.love`,
  `agent.aset.love`, `home.aset.love`: bookmarks, Bitwarden item URIs,
  substituter configs. `cache.aset.love` matters most — narinfo fetches are
  failing.

### Phase F — Payload hygiene (User)

Dead keys, so nothing to migrate — only `sops unset` and a resync. Each has no
consumer in the tree; keep it that way, because removing a declared key while a
module still declares `sops.secrets."<path>"` makes `sops-install-secrets` fail
at activation.

- [ ] (User) F1 `passwords/workd` ([workd.nix](../../../users/home/workd.nix)
  installs `nodejs_26`, no server) and `passwords/nextcloud` (the module is
  commented out of `hosts/yifuwuqi/services.nix`):
  `sops unset secrets/secrets.yaml '["passwords"]["workd"]'` likewise
  `nextcloud`, then `nix run .#secrets`.
- [ ] (User) F2 `services/slskd/web_password` is dead since C1 — slskd renders
  `authentication.disabled: true` and never references the placeholder;
  `tokens/vaultwarden-admin` is dead once `yifuwuqi` switches off Vaultwarden:
  `sops unset secrets/secrets.yaml '["services"]["slskd"]["web_password"]'` and
  (after switching `yifuwuqi`)
  `sops unset secrets/secrets.yaml '["tokens"]["vaultwarden-admin"]'`, then
  `nix run .#secrets`.
- [ ] (User) F3 Confirm the orphans that predate this plan are intended to stay:
  `passwords/filebrowser`, `webdav/htpasswd`, `zerotier/network_id`,
  `services/htpasswd`, `tokens/{gemini,wg-easy,cloudflare-ddclient,cloudflare-acme}`.
  `rg` finds no consumer for any of them. Either `sops unset` each or extend the schema note in
  [secrets.md](../services/secrets.md) with why it is retained.
- [ ] (User) F4 Record in the hosted Bitwarden account the logins that remain
  (Decisions): Forgejo, Seerr, Jellyfin, Pinepods, AdGuard, and the OS password
  behind Cockpit. A reset comes first where the password is unknown
  (CLI/sqlite). The OS login and the Authelia login are stored as crypt and
  argon2id digests in sops, so neither can be recovered — only reset.

### Phase G — Follow-ups (AI)

- [ ] (AI) G1 Authelia OIDC for Forgejo, then disable Forgejo's internal
  sign-in. That removes Forgejo's password without header trust. Pinepods
  (`OIDC_*` env, standard login disabled) can follow on the same provider.

## Rollout order

1. D3 first: nothing else can be judged until a session actually reaches second
   factor.
1. D6 in the same sitting — it is an outage, not a hardening step.
1. D2, D4.
1. E2, F, then the C2 remainder.
1. G after one deploy cycle.

## Open questions

- **Session cookie reaches exempt backends.** `authelia_session` is scoped to
  `aset.love`, so Jellyfin, Pinepods and Attic receive it. A compromised exempt
  backend could replay it against gated services, including OpenCode, which the
  ingress authenticates. Stripping it at the edge needs a `map` over
  `$http_cookie` and a runtime test.
- **Loopback is trusted on `yifuwuqi`.** Any local process can drive the
  backends without a login (\*arr, Bazarr, slskd, qBittorrent, SillyTavern,
  Homepage, SearXNG) and can claim any Grafana user. Containers reach SearXNG
  (read-only, gated at the edge) and, through gluetun's shared namespace only,
  an unauthenticated Lidarr.
- **SearXNG stays reachable from every container subnet.** Firecrawl has no
  fixed address, so narrowing that rule needs the gluetun-style fixed network.
  Accepted: the endpoint is read-only and the browser path is gated.
- **Tailnet listeners bypass the gate.** `yitaishi`'s `sd-cpp` (`11437`) and
  `llama-cpp` (`11436`) answer every tailnet peer.
- **Each gated request costs a second mTLS connection** (the subrequest); there
  is no upstream keepalive on `yirukou` yet.
- **TOTP enrolment needs root** to read the notifier file. SMTP would remove
  that step, and it is also the reason D3 cannot be finished by a browser alone.
- **Pinepods/Firecrawl hardcoded `postgres`/`pinepods` passwords**
  ([pinepods.nix](../../../modules/services/pinepods.nix),
  [firecrawl.nix](../../../modules/services/firecrawl.nix)) are store-visible
  placeholders on internal-only networks; a separate pass.
