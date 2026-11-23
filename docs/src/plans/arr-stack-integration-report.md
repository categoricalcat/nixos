# Arr Stack Integration Review

- Date: 2026-11-23 (evidence gathered 16:00–17:05 America/Sao_Paulo; live checks re-verified after the host reboot at ~16:55)
- Host: `yifuwuqi`
- Scope: Radarr, Sonarr, Lidarr, Readarr, Prowlarr, Bazarr, Jellyfin, Seerr, Recyclarr, qBittorrent+gluetun, torrent-indexer, FlareSolverr, slskd+soularr, Pinepods — the full stack wired in [modules/services/arr/default.nix](../../../modules/services/arr/default.nix), [modules/services/qbittorrent-vpn.nix](../../../modules/services/qbittorrent-vpn.nix), [modules/services/slskd.nix](../../../modules/services/slskd.nix), [modules/services/pinepods.nix](../../../modules/services/pinepods.nix)
- Question asked: is everything integrated, and which of the manual imperative steps ([docs/src/services/arr-stack.md](../../../docs/src/services/arr-stack.md) §§1–9) could have been declarative?

## Verdict

The declarative wiring (ports, binds, ingress, secrets, storage, VPN namespace, maintenance windows, monitoring) is internally consistent and verified live — with three exceptions, all **live failures**:

- **A. soularr cannot reach Lidarr.** Every 5-minute cycle fails with a connect timeout; the automated Soulseek→Lidarr pipeline delivers nothing. Root cause: gluetun's network namespace routes everything but the podman bridge subnet into the VPN tunnel, so `10.42.0.2:24686` never reaches the host. The firewall rule the docs rely on is necessary but not sufficient. Fix is one gluetun env var.
- **B. gluetun's Proton port forwarding is down** since at least the 14:50 restart (PMP RPC refused, retry loop, still failing at 17:04). Root cause is at the Proton account level (WireGuard key without NAT-PMP), not in Nix. The 30-attempt give-up is not a theoretical risk: it exits **cleanly** (status 0), which `Restart=on-failure` ignores, so the cascade stop of the five gluetun consumers is permanent (see §4).
- **C. The port-forwarding up-command could never have worked.** It relies on shell `$1`, but gluetun substitutes `{{PORT}}`/`{{PORTS}}`/`{{VPN_INTERFACE}}` and execs without a shell, so qBittorrent receives invalid JSON. Proved by running gluetun's own argument splitter on the deployed string (appendix E.1): the argument reaching wget is literally `json={"listen_port":$1,...}`. Fixing B alone would still have left `listen_port` unset (see §4b).

The rest of the manual steps are classified below; three are cheaply declarable (qBittorrent save paths, pt-BR custom formats via recyclarr, a redundant secret exposure cleanup). The remaining ones are DB-backed state in the \*arr apps with no env-var mechanism — inherently manual or requiring API-provisioning units.

______________________________________________________________________

## 1. Method

- **Config evaluation** (non-destructive): a self-contained Nix script (appendix A) evaluates `nixosConfigurations.yifuwuqi.config` and prints the whole arr surface — registry, rendered listens, containers, ingress vhosts, firewall rules, unit details, recyclarr config, tmpfiles. Run: `nix eval --json --file /tmp/ai/arr-eval.nix` → exit 0.
- **Live read-only probes** via the `ai-ssh` gate: `systemctl is-active`, `systemctl list-timers`, `journalctl`, `cat /proc/net/tcp{,6}`, `ip addr/neigh`. No state changed anywhere.
- **Upstream sources** pinned/cited: nixpkgs rev `2786a2a72088ecf32aea5b3ec52099e6a7cff78f` (26.11pre1125864) module sources; soularr `master` `soularr.py`; recyclarr config schema; gluetun wiki.
- **Source review of the running images** (added after the live probes, same day): gluetun `master` at `eb3c7ec` plus the commit graph of `qdm12/gluetun` (`fcdba0a3`, `a35c994b`, `efa03037`), recyclarr `v8.8.1` tag, qBittorrent `v5_0_x`, Radarr and Lidarr `master` (`QBittorrent.cs`, `ConfigService.cs`), Prowlarr `master` (`IndexerProxies/Http/`), TRaSH-Guides `docs/json/{radarr,sonarr}/cf/`. Docker Hub tags for `qmcgaw/gluetun`.
- **Not re-checked:** `ai-ssh` was unauthorized from the review host in this second pass, so everything below marked as source-derived rests on code, not a live probe. Live probes are required to confirm them (listed in §7).
- **Executable proofs** (appendix E): every claim that could be settled offline was settled by running the real code — gluetun's own `split` against both command strings, Go regexp against a positive/negative release-title corpus, and a real `recyclarr 8.8.1 sync` against a stub Radarr API. These are example tests over hand-picked inputs; they are evidence, not proof of universal correctness.

## 2. Integration matrix — verified OK

Every link of the chain registry → rendered bind → ingress vhost → firewall → live listener was checked. All consistent.

| Component       | Registry ([hosts.nix](../../../modules/addresses/hosts.nix)) | Rendered bind (eval)                          | Ingress vhost (eval)                     | Live listener (`/proc/net/tcp{,6}`)             |
| --------------- | ------------------------------------------------------------ | --------------------------------------------- | ---------------------------------------- | ----------------------------------------------- |
| radarr          | 24878                                                        | `127.0.0.1:24878`                             | `→ 127.0.0.1:24878`                      | `0100007F:612E` LISTEN                          |
| sonarr          | 24989                                                        | `127.0.0.1:24989`                             | `→ 127.0.0.1:24989`                      | `0100007F:619D` LISTEN                          |
| lidarr          | 24686                                                        | `10.42.0.2:24686` (LAN bind, deliberate)      | `→ 10.42.0.2:24686` (`upstreamLan`)      | `02002A0A:606E` LISTEN                          |
| readarr         | 24787                                                        | `127.0.0.1:24787`                             | `→ 127.0.0.1:24787`                      | `0100007F:60D3` LISTEN                          |
| prowlarr        | 24696                                                        | `127.0.0.1:24696`                             | `→ 127.0.0.1:24696`                      | `0100007F:6078` LISTEN                          |
| bazarr          | 24767                                                        | `127.0.0.1:24767`                             | `→ 127.0.0.1:24767`                      | `0100007F:60BF` LISTEN                          |
| jellyfin        | 24096                                                        | n/a (mutable `network.xml`, preStart rewrite) | `→ 10.42.0.2:24096`                      | `00000000:5E20` LISTEN (0.0.0.0)                |
| seerr           | 24055                                                        | `PORT=24055`, binds `::` (dual-stack)         | `→ 10.42.0.2:24055`                      | tcp6 `::0000:5DF7` LISTEN                       |
| qbittorrent     | 24080                                                        | in gluetun netns                              | `→ 127.0.0.1:24080` (gluetun publish)    | — (netns socket; host publish via gluetun DNAT) |
| slskd           | 24530 (+listen 2234)                                         | in gluetun netns                              | `→ 127.0.0.1:24530` (gluetun publish)    | — (netns socket, see slskd journal)             |
| torrent-indexer | 24181                                                        | in gluetun netns                              | `→ 127.0.0.1:24181` (gluetun publish)    | —                                               |
| flaresolverr    | 24191 (internal 8191)                                        | in gluetun netns                              | n/a (not proxied; docs use host publish) | —                                               |
| pinepods        | 24085                                                        | container `127.0.0.1:24085:8040`              | `→ 127.0.0.1:24085`                      | —                                               |
| ingress         | 24120                                                        | —                                             | listener `10.42.0.2:24120 ssl` (mTLS)    | `02002A0A:5E38` + `0100007F:5E38` LISTEN        |

Other verified integration points:

- **VPN namespace**: gluetun owns it; qbittorrent/flaresolverr/torrent-indexer/slskd/soularr all join via `--network=container:gluetun` (eval `extraOptions`); host publishes go through gluetun (`127.0.0.1:24080:8080`, `:24191:8191`, `:24181:24181`, `:24530:24530`). `podman-gluetun` stops/rms and re-queues all five consumers around restarts ([qbittorrent-vpn.nix](../../../modules/services/qbittorrent-vpn.nix) lines 177–186), and all consumers carry `after`/`bindsTo`/`partOf`. Verified live: all units `active` at the ~16:00 check and again after the 16:55 host reboot; the journals show gluetun restarts at 12:00/14:33/14:50/16:55 with consumers re-queued automatically (soularr resumes its 300 s cycle after each).
- **In-netns wiring**: torrent-indexer → FlareSolverr `http://127.0.0.1:8191` (same netns, eval proof); slskd web on 24530 in-netns reachable by soularr at `127.0.0.1:24530` ([slskd.nix](../../../modules/services/slskd.nix) line 72).
- **Secrets**: five `arr/*_api_key` sops secrets → template `arr-secrets.env` → `*__AUTH__APIKEY` env injection into radarr/sonarr/lidarr/readarr/prowlarr (eval: `EnvironmentFile=["/run/secrets/rendered/arr-secrets.env"]` on each unit); recyclarr gets its keys via systemd `LoadCredential` (`1__run_secrets_arr_radarr_api_key:...`, `2__run_secrets_arr_sonarr_api_key:...`, eval proof). slskd creds, soulseek creds, Proton WG key all declarative via sops templates.
- **Storage**: media dirs pre-created with group-write tmpfiles (eval `mediaTmpfiles`: `/persist/media{,/downloads/{complete,incomplete},/movies,/tv,/music,/books,/podcasts,/downloads/soulseek}` all `2775 root media`); arr units get `UMask=0002`, `PrivateUsers=identity`, `ReadWritePaths=["/persist/media"]` (eval `units.radarr`).
- **Maintenance/monitoring**: recyclarr schedule is wired into the maintenance-slot registry ([maintenance.nix](../../../modules/maintenance.nix) line 49 `slot "*-*-* 04:15:00" "5m"`, line 68) — live timer `recyclarr.timer` active, last trigger 04:17:59, next 04:17:58; the systemd-units dashboard tracks it ([systemd-units.nix](../../../modules/services/monitoring/dashboards/systemd-units.nix) lines 10/12).
- **Firewall**: container subnets reach host DNS and exactly two host APIs (`24686` lidarr, `24888` searxng) — eval of `networking.firewall.extraInputRules` matches [firewall.nix](../../../hosts/yifuwuqi/networking/firewall.nix) lines 80–89. Gateway reaches only the mTLS ingress 24120. (See anomaly A for why the lidarr rule is currently moot.)
- **qBittorrent config enforcement** ([qbittorrent-vpn.nix](../../../modules/services/qbittorrent-vpn.nix) preStart lines 206–221): interface `tun0`, loopback auth disabled, `Session\ShutdownTimeout=5`, ngosang tracker list injection — idempotent every start.

Live unit states (post-reboot, 17:05):

```
$ ai-ssh yifuwuqi systemctl is-active radarr sonarr lidarr readarr prowlarr bazarr \
    seerr jellyfin recyclarr.timer nginx podman-gluetun podman-qbittorrent podman-slskd \
    podman-soularr podman-torrent-indexer podman-flaresolverr podman-pinepods
active × 17
```

## 3. Live failure A — soularr cannot reach Lidarr

**Symptom** (every 5-minute cycle, since at least 14:52, across two boots):

```
nov 23 17:05:03 yifuwuqi soularr[6095]: [ERROR|soularr|L1260] ...: An error occurred when attempting to get records: Timeout occurred while connecting to API.
nov 23 17:05:03 yifuwuqi soularr[6095]: [INFO|soularr|L1669] ...: No releases wanted. Exiting...
```

`get_records` is `lidarr.get_wanted()` (soularr `soularr.py` L1251–1260, master, fetched 2026-11-23) — the call targets the [Lidarr] URL rendered from [slskd.nix](../../../modules/services/slskd.nix) line 66: `http://10.42.0.2:24686`. The automated Soulseek→Lidarr flow has never completed a cycle; slskd itself works (manual Web-UI downloads via VPN fine):

```
nov 23 14:50:28 yifuwuqi slskd[5831]: [17:50:28 INF] Connected to the Soulseek server
nov 23 14:50:29 yifuwuqi slskd[5831]: [17:50:29 INF] Logged in to the Soulseek server as slskyi
```

**Root cause — routing, not firewall.** soularr shares gluetun's netns. Gluetun keeps only the podman bridge subnet on eth0 and routes everything else into the tunnel:

```
$ ai-ssh yifuwuqi journalctl -u podman-gluetun -g "route|routing|firewall|subnet" -n 60 --no-pager
nov 23 16:55:25 ... [routing] local ipnet found: 10.88.0.0/16
nov 23 16:55:25 ... [routing] default route found: interface eth0, gateway 10.88.0.1, assigned IP 10.88.0.2
nov 23 16:55:26 ... [routing] adding route for 0.0.0.0/0
```

`10.42.0.2 ∉ 10.88.0.0/16`, so the SYN enters tun0 and dies in Proton's network. Proof it never reaches the host INPUT chain — with `logRefusedPackets=true` a firewall drop would be logged:

```
$ ai-ssh yifuwuqi journalctl -k -g "24686|10.88.0.2" -n 40 --no-pager
-- No entries --
```

The `extraInputRules` allow (container subnets → `24686`) is therefore necessary but not sufficient; docs §7 "The firewall allows containers to reach Lidarr's API for the import step" overstates what the rule delivers.

**Fix (one line, not applied):** in [qbittorrent-vpn.nix](../../../modules/services/qbittorrent-vpn.nix) gluetun environment:

```nix
FIREWALL_OUTBOUND_SUBNETS = "10.42.0.2/32";
```

Gluetun wiki (setup/options/firewall.md): "`FIREWALL_OUTBOUND_SUBNETS` — Comma separated subnets that Gluetun **and the containers sharing its network stack** are allowed to access. This involves **firewall and routing modifications**." Use the narrow `/32`: the wiki warns a broad `10.x.x.x` entry can overlap the WireGuard tunnel range and break Proton's NAT-PMP (gluetun#3013); Proton's tunnel here is `10.2.0.2/32` with server-side `10.2.0.1`, so `10.42.0.2/32` is unambiguous.

## 4. Live failure B — gluetun Proton port forwarding down

**Symptom** (since the 14:50 gluetun start; still failing at 17:04 on the post-reboot instance; same pattern on both instances today):

```
$ ai-ssh yifuwuqi journalctl -u podman-gluetun -n 6 --no-pager
nov 23 17:04:47 ... ERROR [port forwarding] starting port forwarding service: port forwarding for the first time:
  getting external IPv4 address: executing remote procedure call: connection failed: failed attempts:
  read udp 10.2.0.2:52917->10.2.0.1:5351: recvfrom: connection refused (tries 1..9)
  - make sure you have +pmp at the end of your OpenVPN username or that your Wireguard key is set to work with PMP
  - retrying in 2m40s (attempt 6/30)
```

Config dependency: `PORT_FORWARD_ONLY="on"`, `VPN_PORT_FORWARDING="on"`, `VPN_PORT_FORWARDING_PROVIDER="protonvpn"` ([qbittorrent-vpn.nix](../../../modules/services/qbittorrent-vpn.nix) lines 114–116), and the up-command that pushes the forwarded port into qBittorrent:

```
VPN_PORT_FORWARDING_UP_COMMAND = "wget -O- --retry-connrefused --post-data 'json={\"listen_port\":'$1',...}' http://127.0.0.1:8080/api/v2/app/setPreferences"
```

With PMP refused, the up-command never fires → qBittorrent never gets the Proton forwarded port → degraded seeding/inbound, and docs §3's checklist item ("Verify qBittorrent reports ... the current Proton forwarded port") cannot pass.

**Root cause: account-level.** The Proton WireGuard key in `secrets.yaml` was not generated with NAT-PMP enabled. Fix is manual, outside Nix: regenerate the WireGuard key in the Proton account with port forwarding enabled, update `services/proton/wireguard_private_key`, redeploy.

**Risk to watch — resolved by source review.** The 30-attempt give-up is unconditional. `internal/portforward/retry.go` (`maxRetryAttempts = 30`, `maxRetryDelay = 5 * time.Minute`, ~2 h to exhaustion) reports to `runErrorCh`; `cmd/gluetun/main.go:530` only logs `port forwarding loop crashed: …` and falls through to `orderHandler.Shutdown`, whose nil return makes `_main` return nil and `main` call `os.Exit(0)`. Gluetun therefore exits **cleanly**. `virtualisation/oci-containers.nix:564` sets `Restart = "on-failure"`, which ignores status 0, so the unit stays dead; `bindsTo`/`partOf` stop qbittorrent, slskd, soularr, torrent-indexer and flaresolverr, and only `podman-gluetun`'s `ExecStartPost` ever re-queues them. That is a permanent outage, not a transient one. Alerting is not an available lever: [alertmanager.nix](../../../modules/services/monitoring/alertmanager.nix) is an empty stub and [monitoring.md](../../../docs/src/services/monitoring.md) line 192 states firing alerts do not notify.

**Provenance — B is a two-week-old upstream regression.** The journal's `retrying in 2m40s (attempt 6/30)` string exists only in `efa03037` (2026-11-12, "fix(portforward): retry port forwarding until it works, then give up", #3503). That commit is in **no release tag**; `v3.41.4-rc2`'s `internal/portforward/loop.go` still retries every 5 s forever with no attempt cap. The running image therefore tracks `:latest` from master, not a release. Consequence: the give-up/cascade behaviour arrived days ago and `:latest` remains unpinned, so the PF code path can change again without a flake update.

## 4b. Live failure C — the up-command cannot work as written

Independent of B, the command that would push the forwarded port into qBittorrent is malformed. Deployed value:

```
VPN_PORT_FORWARDING_UP_COMMAND = "wget -O- --retry-connrefused --post-data 'json={\"listen_port\":'$1',\"upnp\":false,\"random_port\":false}' http://127.0.0.1:8080/api/v2/app/setPreferences"
```

Gluetun never invokes a shell. `internal/portforward/service/command.go:16-23` substitutes the templates `{{PORTS}}`, `{{PORT}}` and `{{VPN_INTERFACE}}`, then `command.Split` (`internal/command/split.go:19`, quote/backslash-aware argv split, no expansion) feeds `exec.CommandContext` (`internal/command/startnlog.go:15`). So `$1` reaches wget unmexpanded.

**Proof, not inference** (appendix E): the deployed string was run through gluetun's own `split` implementation, compiled verbatim from `internal/command/split.go`. Result:

```
=== DEPLOYED ===
argv[0] = "wget"
argv[1] = "-O-"
argv[2] = "--retry-connrefused"
argv[3] = "--post-data"
argv[4] = "json={\"listen_port\":$1,\"upnp\":false,\"random_port\":false}"
argv[5] = "http://127.0.0.1:8080/api/v2/app/setPreferences"
```

`argv[4]` is literally `json={"listen_port":$1,...}` — invalid JSON, rejected by `/api/v2/app/setPreferences`. Executing the same payload under `sh` with a stub `wget` that echoes its argv confirms the same argument arrives at the process boundary.

So even with a working NAT-PMP key, qBittorrent would never receive the forwarded port, and docs §3's verification step could not pass. `{{PORT}}` and `{{VPN_INTERFACE}}` are both available: `fcdba0a3` (2025-11-16) and `a35c994b` (2025-11-22), both first released in **v3.41.0** (`git tag --contains` → `v3.41.0`). There is also no `VPN_PORT_FORWARDING_DOWN_COMMAND`; upstream's qBittorrent example sets `listen_port` back to 0 on teardown because the port must be re-set after a reconnect.

Corrected shape (gluetun wiki `setup/advanced/vpn-port-forwarding.md`, "qBittorrent example"):

```
VPN_PORT_FORWARDING_UP_COMMAND = "/bin/sh -c 'wget -O- -nv --retry-connrefused --post-data \"json={\\\"listen_port\\\":{{PORT}},\\\"current_network_interface\\\":\\\"{{VPN_INTERFACE}}\\\",\\\"random_port\\\":false,\\\"upnp\\\":false}\" http://127.0.0.1:8080/api/v2/app/setPreferences'"
VPN_PORT_FORWARDING_DOWN_COMMAND = "/bin/sh -c 'wget -O- -nv --retry-connrefused --post-data \"json={\\\"listen_port\\\":0,\\\"current_network_interface\\\":\\\"lo\\\"}\" http://127.0.0.1:8080/api/v2/app/setPreferences'"
```

**Proof the corrected form works** — same `split`, then executing the resulting shell payload with a stub `wget`:

```
=== PROPOSED ===
argv[0] = "/bin/sh"
argv[1] = "-c"
argv[2] = 'wget -O- -nv --retry-connrefused --post-data "json={\"listen_port\":51413,...}" ...'

# the payload, executed under sh with a stub wget:
ARG=-O-
ARG=-nv
ARG=--retry-connrefused
ARG=--post-data
ARG=json={"listen_port":51413,"current_network_interface":"tun0","random_port":false,"upnp":false}
```

Valid JSON with the substituted port. Two caveats on this evidence: it is an **example test** — one port, one interface — not a universal proof over all gluetun versions; and it was run against gluetun `master`'s `split`, which is the same function in v3.41.x but was not re-verified per release.

Prerequisite already satisfied: in-netns qBittorrent Web UI on `127.0.0.1:8080` with `WebUI\LocalHostAuth=false` (enforced in the preStart).

## 5. Manual-steps inventory — what could be declarative

Auditing [arr-stack.md](../../../docs/src/services/arr-stack.md) §1–9 against the code and the pinned nixpkgs modules (rev `2786a2a72088`): the servarr `settings` option only covers `appsettings.json` sections via `APP__SECTION__KEY` env vars (ports/binds/auth — already declarative here). Root folders, download clients, indexers, application integrations live in each app's SQLite DB — no env-var mechanism exists. Classifications:

- **§1 Initial auth** — per-app first-run UI auth. Manual, inherent (DB). API keys are already declarative (sops env injection).

- **§2 Root folders** (`/persist/media/{movies,tv,music,books}`) — manual (DB). The directories themselves are declarative (tmpfiles proof above). Option: idempotent API-provisioning oneshot (`curl -X POST .../api/v3/rootfolder` with the sops keys) if you want zero-UI bootstrap; otherwise keep documented.

- **§3 qBittorrent save paths — declarable now.** The preStart enforces interface/auth/trackers but not paths; the user set `Downloads\SavePath`/temp path by hand. Add to the crudini block in [qbittorrent-vpn.nix](../../../modules/services/qbittorrent-vpn.nix) (same `[BitTorrent]` section already used):

  ```bash
  crudini --set "$conf" BitTorrent 'Session\DefaultSavePath'  /persist/media/downloads/complete
  crudini --set "$conf" BitTorrent 'Session\TempPathEnabled'  true
  crudini --set "$conf" BitTorrent 'Session\TempPath'         /persist/media/downloads/incomplete
  ```

  Key shape proven twice over (appendix E): `session.h:393` defines `BITTORRENT_SESSION_KEY(name)` as `BitTorrent/Session/` + name, and `sessionimpl.cpp:503-505` instantiates exactly `DefaultSavePath`, `TempPath`, `TempPathEnabled` — so the INI section is `[BitTorrent]` and the key is `Session\X`. A crudini round trip (crudini 0.9.6) on a scratch file emits the expected lines:

  ```
  [BitTorrent]
  Session\DefaultSavePath = /persist/media/downloads/complete
  Session\TempPathEnabled = true
  Session\TempPath = /persist/media/downloads/incomplete
  ```

  Still unverified: that the deployed image is 5.x. `docker.io/linuxserver/qbittorrent:latest` was not inspected; read the live conf before enforcing.
  (verify key names against the deployed `qBittorrent.conf` once; v5.x uses `[BitTorrent] Session\*`.) The forwarded-port verification half of §3 is blocked by anomalies B and C.

- **§4 Download-client entries in each arr app** — manual (DB). Same API-provisioning option as §2, else documented. **Correction from source review: the `music` category needs no provisioning.** Radarr and Lidarr create missing qBittorrent categories themselves when the download client is saved or tested: `TestCategory()` → `GetLabels()` → on absence `AddLabel()` → `POST /api/v2/torrents/createCategory` (Lidarr `src/NzbDrone.Core/Download/Clients/QBittorrent/QBittorrent.cs:541`, Radarr `:557`). qBittorrent then persists them to `categories.json` in its config dir (`SessionImpl::storeCategories`), not to `qBittorrent.conf` — which is why they are absent from the declarative surface without being a gap.

- **§5 Prowlarr indexers + app integrations + FlareSolverr proxy** — manual (DB). The plumbing they point at is verified correct (matrix above: 24181, 24191, 24878/24989/24686/24787 all live).

- **§6 Recyclarr** — declarative, but the docs' "fully declarative ... syncs the configured TRaSH profiles" overstates: the rendered config syncs radarr-main + sonarr-main, quality definitions + `All-in-One` profiles only (eval proof, appendix B). Live journal confirms exactly that scope:

  ```
  04:18:02 [INF] radarr-main: Processing Radarr server radarr-main
  04:18:03 [INF] radarr-main: All custom formats are already up to date!
  04:18:03 [INF] sonarr-main: Processing Sonarr server sonarr-main
  ```

  Lidarr/Readarr absence is a **capability limit, not an omission**: the recyclarr config schema (schemas.recyclarr.dev/latest/config-schema.json) admits only `sonarr` and `radarr` top-level sections.

- **§7 Soulseek** — account creation at slsknet.org is a one-time external step; credentials, slskd.yml, soularr.ini are fully declarative (sops). The automated flow is currently dead (anomaly A).

- **§8 pt-BR custom formats — declarable now, but the documented regex is wrong and recyclarr cannot express it directly.** Today: manual regex + scoring in Radarr/Sonarr UIs.
  **Two independent findings.**
  (a) *The docs' pattern under-matches.* Running `(?i)\b(dublado|dual(\W)?audio|pt(\W)?br)\b` against a release-title corpus (appendix E) misses 3 of 9 positives, each for a distinct, measured reason:

  | Title                   | Why it misses                                                                                  |
  | ----------------------- | ---------------------------------------------------------------------------------------------- |
  | `Dual-Áudio`            | the alternation requires literal ASCII `audio`; the accent `Á` is not matched                  |
  | `DUALÁUDIO`             | same cause — accented `Áudio`, not the missing separator (`DUALAUDIO` unaccented *does* match) |
  | `MOVIE_2024_DUBLADO_4K` | `_` is a word character, so `\b` never fires around `DUBLADO`                                  |

  0 false positives in this corpus. A corrected pattern — `(?i)(?:^|[^a-z0-9])(dublado|dual[\W_]?(?:[aá]udio)|pt[\W_]?br)(?:$|[^a-z0-9])` — satisfies all 9 positives and all 9 negatives in the same corpus, including the trap `Movie.2024.1080p.dualpixel.art`.
  (b) *Recyclarr 8.8.1 cannot hold a custom specification.* `custom_formats` accepts only `trash_ids` (`ServiceConfiguration.cs:28-30`), and the guide ships no pt-BR CF. A literal regex requires a **local resource provider**: `settings.yml` with `resource_providers: [{name, type: custom-formats, service: radarr|sonarr, path}]` plus one JSON whose `specifications[].implementation` is `ReleaseTitleSpecification`. The nixpkgs module generates only `config.yml` (`misc/recyclarr.nix:13,112`) and has no `settings.yml` option, so the unit must install it.
  **Both proven end-to-end** (appendix E): a real `recyclarr 8.8.1 sync radarr` against a stub Radarr API — with a local `custom-formats` provider and no `score` in the instance config — POSTed the CF and scored the profile:

  ```
  BODY /api/v3/customformat {"name":"pt-BR Dubbed / Dual Audio","specifications":[{"implementation":"ReleaseTitleSpecification",...}]}
  BODY /api/v3/qualityprofile/1 {..."formatItems": [{"format": 0, "name": "pt-BR Dubbed / Dual Audio", "score": 50}]}
  ```

  The 50 came from the format JSON's `trash_scores.default`, not from instance config — `DetermineScore` (`QualityProfilePlanComponent.cs:174-193`) precedence is explicit `score` > `score_set` > `DefaultScore`. So the score has exactly one home.

- **§9 Pinepods** — first admin account is app-design manual; state/volumes declarative. Note: `POSTGRES_PASSWORD`/`DB_PASSWORD` are the hardcoded string `pinepods` ([pinepods.nix](../../../modules/services/pinepods.nix) lines 80/118) — acceptable for the `pinepods_internal`-only network (no host publish), but it is a non-secret placeholder in the store; flag for a later pass.

One-time pre-deploy steps (§0): generating the `arr:` API-key block into `secrets.yaml` with the documented `openssl rand` loop — imperative by design (secrets live outside the flake).

## 6. Docs-vs-code mismatches and cleanup candidates

- **§6 claim "Recyclarr is fully declarative"** — see §5 above; also "injected into the applications and Recyclarr via environment variables" is imprecise: Recyclarr receives keys via systemd `LoadCredential` from `_secret` paths, not env vars. The nixpkgs module additionally generates only `config.yml`; a `settings.yml` (needed for any local resource provider) has no option and must be installed by the unit.
- **§8's parenthetical fix is not available as stated** — it says the custom format "can" be defined via recyclarr in [arr/default.nix](../../../modules/services/arr/default.nix). Recyclarr's `custom_formats` is trash-id-only; a pt-BR regex needs a local `custom-formats` provider (§5). The regex it recommends is also buggy: it misses `Dual-Áudio`, `DUALÁUDIO` and `_DUBLADO_` (§5).
- **§4 "Category: `music` ... must exist in qBittorrent"** — unnecessary: the arr app creates the category on client save/test (§5).
- **§8 indexer scope** — [arr-stack.md](../../../docs/src/services/arr-stack.md) §8 tells the reader to "sync it to Radarr and Sonarr"; Prowlarr will refuse Lidarr for LimeTorrents (already documented) but the pt-BR indexer syncs fine. No change needed; noted so a future reader does not "fix" it.
- **§7 claim "The firewall allows containers to reach Lidarr's API for the import step"** — the rule exists but the path is broken by gluetun routing (anomaly A). After the `FIREWALL_OUTBOUND_SUBNETS` fix the sentence becomes true; today it is not. Worth adding the converse hazard: `FIREWALL_OUTBOUND_SUBNETS` installs a **destination-wide** OUTPUT accept inside the netns (all ports on `10.42.0.2` become reachable for every container sharing the namespace); the host's `extraInputRules` stays the port-level gate and must not be widened.
- **`127.0.0.1:8889:8888` gluetun publish** (HTTP proxy, `HTTPPROXY=on`) — not in the address registry, not proxied, undocumented in arr-stack.md. **Not dead config.** Repo text search finds no consumer, but the plausible ones are DB state and invisible to grep: Prowlarr's "Http" indexer proxy (`IndexerProxies/Http/HttpSettings.cs`: Host/Port/Username/Password, applied per request in `Http.cs`) and each arr app's own proxy settings (`ConfigService.cs:420-434`: `ProxyEnabled`, `ProxyType`, `ProxyHostname`, `ProxyPort`, `ProxyBypassLocalAddresses`). Since `f7fbaad` (2026-11-09) the publish is loopback-only, so any consumer configured with `10.42.0.2:8889` or the tailnet address has been silently failing for two weeks. gluetun defaults to no credentials (`HTTPPROXY_USER`/`HTTPPROXY_PASSWORD` empty), so any local process can use it as a VPN egress; the loopback bind is the only mitigation today.
- **Jellyfin port rewrite only patches an existing `network.xml`** ([arr/default.nix](../../../modules/services/arr/default.nix) lines 200–213): on a genuinely first deploy Jellyfin binds the default port until the file exists and the unit restarts. Live host is fine (`0.0.0.0:24096` LISTEN); worth a note in the bootstrap docs.
- **Redundant secret exposure**: `recyclarr.serviceConfig.EnvironmentFile = envFile` ([arr/default.nix](../../../modules/services/arr/default.nix) line 234) feeds the five `*__AUTH__APIKEY` vars to a Python app that never reads them — recyclarr's real key path is `LoadCredential` (eval proof). Dead config that widens secret visibility to the `recyclarr` user's environment; safe to delete.
- **Recyclarr timer docs** — §6 says "daily"; actual schedule is the maintenance slot `*-*-* 04:15:00` + `RandomizedDelaySec=5m` (live triggers at 04:17–04:18). Minor wording fix.
- **Unpinned gluetun image** — `image = "docker.io/qmcgaw/gluetun:latest"` ([qbittorrent-vpn.nix](../../../modules/services/qbittorrent-vpn.nix) line 100). Anomaly B's give-up behaviour and the `{{PORT}}` capability both depend on which master commit that tag currently points at; a release pin (v3.41.4 or later) would make the PF code path knowable. Not a bug today, a reproducibility gap.

## 7. Recommended follow-ups (report-only; nothing applied)

1. `FIREWALL_OUTBOUND_SUBNETS = "10.42.0.2/32"` on gluetun — fixes anomaly A end-to-end (routing + firewall), verified semantics per gluetun wiki.
1. Proton account: WireGuard key with NAT-PMP enabled — fixes anomaly B at its root.
1. `Restart = lib.mkForce "always"` (or `RestartForceExitStatus = [ 0 ]`) on `podman-gluetun` — a PF give-up exits 0, which `Restart=on-failure` ignores, leaving the whole stack down. No alerting path exists, so restart is the only automatic remedy.
1. Replace the PF up-command with the `{{PORT}}`/`{{VPN_INTERFACE}}` form run through `/bin/sh -c`, and add the down-command — anomaly C; without it, fixing B still leaves `listen_port` unset.
1. qBittorrent preStart: enforce save paths (+ temp path). **Drop the `music`-category provisioning idea**: the arr app creates it.
1. Recyclarr: add the pt-BR custom format via a local `custom-formats` provider (settings.yml + JSON), since trash-id-only config cannot express it. Use the corrected regex from appendix E.2, not the one in the docs.
1. Delete the recyclarr `EnvironmentFile` line (cleanup candidate).
1. Docs pass on arr-stack.md: §4 category claim, §6 wording/scope, §7 routing caveat (or fix note after 1.), §8 mechanism and regex, register the 8889 publish, jellyfin first-boot note.
1. Pin the gluetun image instead of `:latest`.
1. Optional: API-provisioning oneshots for root folders / download clients / Prowlarr app integrations if zero-UI bootstrap is wanted (idempotent `curl` units using the sops keys) — larger surface, only if the manual steps keep hurting.

______________________________________________________________________

## Appendix A — evaluation script and command

Saved at `/tmp/ai/arr-eval.nix`; reproduce with `nix eval --json --file /tmp/ai/arr-eval.nix` from anywhere (it does `builtins.getFlake "/home/yi/the.files/nixos"` internally). Exit 0; output at `/tmp/ai/arr-eval.json` (10,622 bytes).

```nix
# Self-contained: evaluates the yifuwuqi config and selects the arr-stack
# surface (registry, rendered ports, containers, ingress, firewall, units).
let
  f = builtins.getFlake "/home/yi/the.files/nixos";
  cfg = f.nixosConfigurations.yifuwuqi.config;
  allAddresses = import "/home/yi/the.files/nixos/modules/addresses.nix";
  yif = allAddresses.hosts.yifuwuqi;

  oci = cfg.virtualisation.oci-containers.containers;
  svc = cfg.systemd.services;
  vs = cfg.services.nginx.virtualHosts;

  arrVhostDetail =
    n:
    let v = vs.${n}; in
    {
      listen = v.listen or [ ];
      proxyPass = (v.locations or { })."/".proxyPass or null;
    };

  mediaDirs = r: builtins.match ".*/persist/media.*" r != null;
in
{
  registry = {
    radarr = yif.services.radarr;
    sonarr = yif.services.sonarr;
    lidarr = yif.services.lidarr;
    readarr = yif.services.readarr;
    prowlarr = yif.services.prowlarr;
    bazarr = yif.services.bazarr;
    qbittorrent = yif.services.qbittorrent;
    slskd = yif.services.slskd;
    torrent-indexer = yif.services.torrent-indexer;
    flaresolverr = yif.services.flaresolverr;
    jellyfin = yif.services.jellyfin;
    jellyseerr = yif.services.jellyseerr;
    pinepods = yif.services.pinepods;
  };

  rendered = {
    radarr = cfg.services.radarr.settings.server;
    sonarr = cfg.services.sonarr.settings.server;
    lidarr = cfg.services.lidarr.settings.server;
    readarr = cfg.services.readarr.settings.server;
    prowlarr = cfg.services.prowlarr.settings.server;
    bazarr = cfg.services.bazarr.settings.general;
    seerr = { port = cfg.services.seerr.port; };
  };

  containers = {
    gluetun = {
      ports = oci.gluetun.ports;
      upCommand = oci.gluetun.environment.VPN_PORT_FORWARDING_UP_COMMAND or null;
      netns = oci.gluetun.networkNamespace or null;
    };
    qbittorrent = {
      ports = oci.qbittorrent.ports or [ ];
      volumes = oci.qbittorrent.volumes;
    };
    flaresolverr = oci.flaresolverr.environment or { };
    torrent-indexer = {
      environment = oci.torrent-indexer.environment or { };
      extraOptions = oci.torrent-indexer.extraOptions or [ ];
    };
    slskd = {
      volumes = oci.slskd.volumes or [ ];
      extraOptions = oci.slskd.extraOptions or [ ];
    };
    soularr = {
      volumes = oci.soularr.volumes or [ ];
      environment = oci.soularr.environment or { };
    };
    pinepods = { ports = oci.pinepods.ports or [ ]; };
  };

  nginxHosts = builtins.attrNames vs;
  arrVhosts = {
    radarr = arrVhostDetail "radarr.aset.love";
    sonarr = arrVhostDetail "sonarr.aset.love";
    lidarr = arrVhostDetail "lidarr.aset.love";
    readarr = arrVhostDetail "readarr.aset.love";
    prowlarr = arrVhostDetail "prowlarr.aset.love";
    bazarr = arrVhostDetail "bazarr.aset.love";
    qbittorrent = arrVhostDetail "qbittorrent.aset.love";
    slskd = arrVhostDetail "slskd.aset.love";
    torrent-indexer = arrVhostDetail "torrent-indexer.aset.love";
    jellyfin = arrVhostDetail "jellyfin.aset.love";
    jellyseerr = arrVhostDetail "jellyseerr.aset.love";
    cast = arrVhostDetail "cast.aset.love";
  };

  extraInputRules = cfg.networking.firewall.extraInputRules;
  appSourceSubnets = allAddresses.hosts.yifuwuqi.containers.isolation.applicationSourceSubnets or null;

  units = {
    radarr = {
      serviceConfig = {
        UMask = svc.radarr.serviceConfig.UMask or null;
        PrivateUsers = svc.radarr.serviceConfig.PrivateUsers or null;
        ReadWritePaths = svc.radarr.serviceConfig.ReadWritePaths or [ ];
        EnvironmentFile = svc.radarr.serviceConfig.EnvironmentFile or [ ];
      };
    };
    recyclarr = {
      serviceConfig = svc.recyclarr.serviceConfig;
      preStart = svc.recyclarr.preStart or [ ];
    };
    jellyfin = { preStart = svc.jellyfin.preStart or [ ]; };
  };

  recyclarr = {
    enable = cfg.services.recyclarr.enable;
    schedule = cfg.services.recyclarr.schedule;
    command = cfg.services.recyclarr.command;
    configuration = cfg.services.recyclarr.configuration;
  };

  templateNames = builtins.attrNames cfg.sops.templates;
  templateCount = builtins.length (builtins.attrNames cfg.sops.templates);

  mediaTmpfiles = builtins.filter mediaDirs (
    builtins.map
    (r: if builtins.isAttrs r then r.rule or "" else r)
    cfg.systemd.tmpfiles.rules
  );
}
```

## Appendix B — key eval outputs (proof excerpts)

```
$ jq -r '.registry | to_entries[] | "\(.key): \(.value.domain) port=\(.value.port)"' /tmp/ai/arr-eval.json
bazarr: bazarr.aset.love port=24767
flaresolverr: flaresolverr.aset.love port=24191
jellyfin: jellyfin.aset.love port=24096
jellyseerr: jellyseerr.aset.love port=24055
lidarr: lidarr.aset.love port=24686
pinepods: cast.aset.love port=24085
prowlarr: prowlarr.aset.love port=24696
qbittorrent: qbittorrent.aset.love port=24080
radarr: radarr.aset.love port=24878
readarr: readarr.aset.love port=24787
slskd: slskd.aset.love port=24530
sonarr: sonarr.aset.love port=24989
torrent-indexer: torrent-indexer.aset.love port=24181

$ jq -c '.rendered' /tmp/ai/arr-eval.json
{"bazarr":{"auto_update":false,"ip":"127.0.0.1","port":24767},"lidarr":{"bindaddress":"10.42.0.2","port":24686},
 "prowlarr":{"bindaddress":"127.0.0.1","port":24696},"radarr":{"bindaddress":"127.0.0.1","port":24878},
 "readarr":{"bindaddress":"127.0.0.1","port":24787},"seerr":{"port":24055},"sonarr":{"bindaddress":"127.0.0.1","port":24989}}

$ jq -r '.arrVhosts | to_entries[] | "\(.key): \(.value.proxyPass)"' /tmp/ai/arr-eval.json
bazarr: http://127.0.0.1:24767          lidarr: http://10.42.0.2:24686
cast: http://127.0.0.1:24085           prowlarr: http://127.0.0.1:24696
jellyfin: http://10.42.0.2:24096       qbittorrent: http://127.0.0.1:24080
jellyseerr: http://10.42.0.2:24055     radarr: http://127.0.0.1:24878
readarr: http://127.0.0.1:24787        slskd: http://127.0.0.1:24530
sonarr: http://127.0.0.1:24989         torrent-indexer: http://127.0.0.1:24181

$ jq -c '[.arrVhosts[].listen[0]] | unique' /tmp/ai/arr-eval.json
[{"addr":"10.42.0.2","port":24120,"ssl":true}]

$ jq -c '.containers.gluetun' /tmp/ai/arr-eval.json
{"netns":null,"ports":["127.0.0.1:24080:8080","127.0.0.1:8889:8888","127.0.0.1:24191:8191",
 "127.0.0.1:24181:24181","127.0.0.1:24530:24530"],
 "upCommand":"wget -O- --retry-connrefused --post-data 'json={\"listen_port\":'$1',\"upnp\":false,\"random_port\":false}' http://127.0.0.1:8080/api/v2/app/setPreferences"}

$ jq -c '.units.radarr' /tmp/ai/arr-eval.json
{"serviceConfig":{"EnvironmentFile":["/run/secrets/rendered/arr-secrets.env"],"PrivateUsers":"identity",
 "ReadWritePaths":["/persist/media"],"UMask":"0002"}}

$ jq -c '{User:.units.recyclarr.serviceConfig.User, Type:.units.recyclarr.serviceConfig.Type,
  EnvironmentFile:.units.recyclarr.serviceConfig.EnvironmentFile,
  LoadCredential:.units.recyclarr.serviceConfig.LoadCredential}' /tmp/ai/arr-eval.json
{"User":"recyclarr","Type":"oneshot","EnvironmentFile":"/run/secrets/rendered/arr-secrets.env",
 "LoadCredential":["1__run_secrets_arr_radarr_api_key:/run/secrets/arr/radarr_api_key",
                   "2__run_secrets_arr_sonarr_api_key:/run/secrets/arr/sonarr_api_key"]}

$ jq -r '.recyclarr' /tmp/ai/arr-eval.json
{ "command": "sync", "enable": true, "schedule": "*-*-* 04:15:00",
  "configuration": { "radarr": { "radarr-main": { "api_key": {"_secret": "..."}, "base_url": "http://127.0.0.1:24878",
      "quality_definition": {"type":"movie"}, "quality_profiles": [{"name":"All-in-One"}] } },
                    "sonarr": { "sonarr-main": { "api_key": {"_secret": "..."}, "base_url": "http://127.0.0.1:24989",
      "quality_definition": {"type":"series"}, "quality_profiles": [{"name":"All-in-One"}] } } } }

$ jq -c '.templateNames' /tmp/ai/arr-eval.json
["arr-secrets.env","cloudflared.env","gluetun.env","opencode.env","qbittorrent.conf","slskd.yml","soularr.ini"]

$ jq -r '.extraInputRules' /tmp/ai/arr-eval.json
ip saddr { 10.88.0.0/16, 172.17.0.0/16, 172.18.0.0/16 } udp dport 53 accept comment "allow container dns udp"
ip saddr { 10.88.0.0/16, 172.17.0.0/16, 172.18.0.0/16 } tcp dport 53 accept comment "allow container dns tcp"
ip saddr { 10.88.0.0/16, 172.17.0.0/16, 172.18.0.0/16 } tcp dport {
  24686, 24888
} accept comment "allow containers to specific host apis"
```

## Appendix C — live proof commands

```
$ ai-ssh yifuwuqi systemctl list-timers --all | grep -i recyclarr
Tue 2026-11-24 04:17:58 -03  12h  Mon 2026-11-23 04:17:59 -03  - recyclarr.timer  recyclarr.service

$ ai-ssh yifuwuqi journalctl -u recyclarr.service --since "2026-11-23 04:17" --no-pager
04:18:02 [INF] Initializing provider: official (type: trash-guides)
04:18:02 [INF] radarr-main: Processing Radarr server radarr-main
04:18:03 [INF] radarr-main: All custom formats are already up to date!
04:18:03 [INF] radarr-main: All sizes for quality definition movie are already up to date!
04:18:03 [INF] radarr-main: All quality profiles are up to date!
04:18:03 [INF] sonarr-main: Processing Sonarr server sonarr-main
04:18:03 [INF] sonarr-main: All custom formats are already up to date!
04:18:03 [INF] sonarr-main: All quality profiles are up to date!

$ ai-ssh yifuwuqi journalctl -u podman-soularr -n 6 --no-pager          # anomaly A, post-reboot
17:02:49 [INFO|soularr|L1215] Logging to file: /data/soularr.log
17:05:03 [ERROR|soularr|L1260] An error occurred when attempting to get records: Timeout occurred while connecting to API.
17:05:03 [INFO|soularr|L1669] No releases wanted. Exiting...

$ ai-ssh yifuwuqi journalctl -k -g "24686|10.88.0.2" -n 40 --no-pager
-- No entries --

$ ai-ssh yifuwuqi journalctl -u podman-gluetun -g "route|routing|firewall|subnet" -n 60 --no-pager
16:55:25 [routing] local ipnet found: 10.88.0.0/16
16:55:25 [routing] default route found: interface eth0, gateway 10.88.0.1, assigned IP 10.88.0.2
16:55:26 [routing] adding route for 0.0.0.0/0
```

## Appendix D — upstream citations

- soularr `get_records` → `lidarr.get_wanted`: `soularr.py` L1251–1260 (mrusse/soularr master, fetched 2026-11-23); timeout wrapped by `PyarrConnectionError` per L24–26.
- recyclarr supported instances: config schema `https://schemas.recyclarr.dev/latest/config-schema.json` — top-level `properties` = `sonarr`, `radarr` only.
- gluetun `FIREWALL_OUTBOUND_SUBNETS` (routing + firewall, shared-netns containers included; overlap caveat): `qdm12/gluetun-wiki` `setup/options/firewall.md`.
- nixpkgs modules (rev `2786a2a72088ecf32aea5b3ec52099e6a7cff78f`): `nixos/modules/services/misc/servarr/*` (INI `settings` → `APP__SECTION__KEY` env), `misc/bazarr.nix` (DYNACONF settings, `_secret`), `misc/seerr.nix` (`PORT` only, no bind option), `misc/recyclarr.nix` (`schedule`, `LoadCredential` via `genJqSecretsReplacement`, **no** `settings.yml` option), `nixos/modules/virtualisation/oci-containers.nix:564` (`Restart = "on-failure"`).

### gluetun (`qdm12/gluetun`, source review 2026-11-23)

| Path                                           | Fact used                                                                                                         |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `cmd/gluetun/main.go:322-325`                  | `FIREWALL_OUTBOUND_SUBNETS` drives **both** `firewallConf.SetOutboundSubnets` and `routingConf.SetOutboundRoutes` |
| `internal/routing/outbound.go`                 | escape route in table `199`, ip-rule priority `99`                                                                |
| `internal/vpn/wireguard.go`                    | WireGuard fwmark rule priority `101`, so 99 wins for listed destinations                                          |
| `internal/firewall/outboundsubnets.go`         | `AcceptOutputFromIPToSubnet` — destination-wide OUTPUT accept, all ports                                          |
| `internal/portforward/retry.go`                | `maxRetryAttempts = 30`, `maxRetryDelay = 5m`, retry string `retrying in %s (attempt %d/%d)`                      |
| `cmd/gluetun/main.go:530`                      | PF loop error is only logged; shutdown returns nil → `os.Exit(0)`                                                 |
| `internal/portforward/service/command.go`      | substitutes `{{PORTS}}`, `{{PORT}}`, `{{VPN_INTERFACE}}`; no shell                                                |
| `internal/command/split.go`, `startnlog.go`    | argv split (quotes/backslashes honoured, no expansion) then `exec.CommandContext`                                 |
| `internal/portforward/service/start.go`        | auto-redirects when internal≠external port; user `ListeningPorts` takes precedence                                |
| `internal/configuration/settings/httpproxy.go` | default `:8888`, `HTTPPROXY_USER`/`PASSWORD` default empty                                                        |
| commit `fcdba0a3` (2025-11-16)                 | `{{PORT}}` added; first release **v3.41.0**                                                                       |
| commit `a35c994b` (2025-11-22)                 | `{{VPN_INTERFACE}}` added; first release **v3.41.0**                                                              |
| commit `efa03037` (2026-11-12)                 | the 30-attempt give-up (#3503); **in no release tag** — `v3.41.4-rc2` still retries indefinitely                  |

### recyclarr v8.8.1

| Path                                                                           | Fact used                                                                      |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `schemas/config/custom-formats.json`                                           | entries are `{trash_ids, score?, assign_scores_to?}` — no inline specification |
| `src/Recyclarr.Core/Config/Models/ServiceConfiguration.cs`                     | `CustomFormatConfig`, `AssignScoresToConfig`                                   |
| `src/Recyclarr.Core/ResourceProviders/Domain/CustomFormatResource.cs`          | `trash_scores` → `DefaultScore`; `specifications`                              |
| `src/Recyclarr.Core/TrashGuide/CustomFormat/FieldsArrayJsonConverter.cs`       | `fields` may be an object or array                                             |
| `src/Recyclarr.Core/ResourceProviders/Infrastructure/CustomFormatsStrategy.cs` | `type: custom-formats` + `service` + local `path`                              |
| `src/Recyclarr.Core/ResourceProviders/Storage/LocalProviderLocation.cs`        | relative paths resolve under `RECYCLARR_CONFIG_DIR`                            |
| `src/Recyclarr.Cli/Pipelines/CustomFormat/ConfiguredCustomFormatProvider.cs`   | `assign_scores_to` by `name` or `trash_id`                                     |

### qBittorrent `v5_0_x` / arr apps

- `src/base/bittorrent/session.h`: `BITTORRENT_SESSION_KEY(name)` = `BitTorrent/Session/` + name; used for `DefaultSavePath`, `TempPath`, `TempPathEnabled`.
- `src/base/bittorrent/sessionimpl.cpp`: `storeCategories`/`loadCategories` — categories live in `categories.json`, not the INI.
- `src/base/bittorrent/categoryoptions.cpp`: `save_path`/`download_path` JSON keys.
- `src/webui/api/torrentscontroller.cpp:1296` `createCategoryAction`; `torrentimpl.cpp:1607` `setCategory` rejects unknown categories.
- Radarr `src/NzbDrone.Core/Download/Clients/QBittorrent/QBittorrent.cs:557` / Lidarr `:541`: `TestCategory` → `AddLabel` creates the category on client save/test.
- Radarr `src/NzbDrone.Core/Configuration/ConfigService.cs:420-434`: `ProxyEnabled`, `ProxyType`, `ProxyHostname`, `ProxyPort`, `ProxyBypassLocalAddresses`.
- Prowlarr `src/NzbDrone.Core/IndexerProxies/Http/{HttpSettings,Http}.cs`: indexer-level HTTP proxy with host/port/user/pass.

## Appendix E — executable proofs

Everything here was executed on this host on 2026-11-23; scripts live under `/tmp/ai/` (scratch, not committed). Each block states what it establishes and — importantly — what it does **not**.

### E.1 gluetun's own argv split, on both command strings

*Establishes*: the deployed up-command passes `$1` to wget as a literal, producing invalid JSON; the proposed `/bin/sh -c` form with `{{PORT}}` produces valid JSON for the substituted port.

*Does not establish*: behaviour for multiple forwarded ports (`{{PORTS}}`), IPv6, or gluetun versions older than v3.41.0. The `split` source is gluetun `master`; it was not diffed against each release tag.

Script: `/tmp/ai/splitproof/` (a verbatim copy of `internal/command/split.go` with `split` exported as `Split`, plus a `main.go` reproducing `command.go`'s substitution).

The deployed input was not retyped: it is the live evaluated value, `nix eval --raw .#nixosConfigurations.yifuwuqi.config.virtualisation.oci-containers.containers.gluetun.environment.VPN_PORT_FORWARDING_UP_COMMAND`, saved to `/tmp/ai/rendered_upcmd.txt`.

```
$ cd /tmp/ai/splitproof
$ CURRENT_CMD='wget -O- --retry-connrefused --post-data '"'"'json={"listen_port":'"'"'$1'"'"',"upnp":false,"random_port":false}'"'"' http://127.0.0.1:8080/api/v2/app/setPreferences' \
  nix shell nixpkgs#go -c sh -c 'go run .'
rendered: wget -O- --retry-connrefused --post-data 'json={"listen_port":'$1',"upnp":false,"random_port":false}' http://127.0.0.1:8080/api/v2/app/setPreferences
argv[4] = "json={\"listen_port\":$1,\"upnp\":false,\"random_port\":false}"

$ PROPOSED_CMD='/bin/sh -c '"'"'wget -O- -nv --retry-connrefused --post-data "json={\"listen_port\":{{PORT}},...}" http://127.0.0.1:8080/api/v2/app/setPreferences'"'"'' \
  nix shell nixpkgs#go -c sh -c 'go run .'
argv[0] = "/bin/sh"
argv[1] = "-c"
argv[2] = "wget -O- -nv ... \"listen_port\":51413 ..."

# and executing that payload with a stub wget that echoes argv:
ARG=--post-data
ARG=json={"listen_port":51413,"current_network_interface":"tun0","random_port":false,"upnp":false}
```

### E.2 The pt-BR regex, against a hand-built corpus

*Establishes*: the documented pattern misses three realistic release-name shapes, each for a distinct reason (accented `Áudio` ×2, and `_` defeating `\b`); the replacement matches all 9 positives and rejects all 9 negatives in this corpus.

*Does not establish*: broad coverage. The corpus is hand-picked (9+9); this is an example test, not a property test with a generator, and real indexer titles vary far more. A false positive on a real release is still possible.

Script: `/tmp/ai/regexproof/`.

```
$ cd /tmp/ai/regexproof && nix shell nixpkgs#go -c sh -c 'go run .'
  [plan (literal from arr-stack.md)] MISS: Movie 2024 720p Dual-Áudio BluRay
  [plan (literal from arr-stack.md)] MISS: MOVIE_2024_DUBLADO_4K
  [plan (literal from arr-stack.md)] MISS: Movie.2024.DUALÁUDIO.1080p
plan (literal from arr-stack.md)   positives missed=3/9  false-positives=0/9
proposed v2                        positives missed=0/9  false-positives=0/9

# isolated causes:
Dual-Áudio  -> false  (requires literal 'audio'; accented 'Áudio' does not match)
_DUBLADO_   -> false  ('_' is a word char, so \b never fires)
DUALAUDIO   -> true   (missing separator alone is fine)
```

The replacement: `(?i)(?:^|[^a-z0-9])(dublado|dual[\W_]?(?:[aá]udio)|pt[\W_]?br)(?:$|[^a-z0-9])`.

### E.3 A real recyclarr sync, against a stub Radarr

*Establishes*: recyclarr 8.8.1 (the pinned nixpkgs build) loads a local `custom-formats` resource provider, resolves the CF, POSTs it with `ReleaseTitleSpecification`, and applies `trash_scores.default` as the profile score. Config parse, provider init, CF creation and profile scoring are all exercised by real code, not read from source.

*Does not establish*: Sonarr parity (only `sync radarr` was run — `list custom-formats sonarr` does show the CF), behaviour against the real Radarr (the stub returns minimal fixtures), or that `preStart`-installed files persist correctly under systemd's `StateDirectory`.

Script: `/tmp/ai/cfproof/` (config + `settings.yml` + CF JSON) and `/tmp/ai/fakeradarr/srv.py` (stub API).

```
$ RECYCLARR_CONFIG_DIR=/tmp/ai/cfproof/cfg RECYCLARR_DATA_DIR=/tmp/ai/cfproof/data \
  nix run nixpkgs#recyclarr -- sync radarr
[INF] Initializing provider: ptbr-radarr (type: custom-formats)
[INF] radarr-main: Created 1 New Custom Formats
[INF] radarr-main: Updated 1 Profiles: ["All-in-One"]
[INF] radarr-main: A total of 1 profiles were synced. 0 contain quality changes and 1 contain updated scores

# stub server captured:
BODY /api/v3/customformat {"name": "pt-BR Dubbed / Dual Audio",
  "specifications": [{"name": "pt-BR", "implementation": "ReleaseTitleSpecification", ...}]}
BODY /api/v3/qualityprofile/1 {..."formatItems": [{"format": 0,
  "name": "pt-BR Dubbed / Dual Audio", "score": 50}]}
```

Score resolution precedence verified in the same source: `DetermineScore` (`src/Recyclarr.Cli/Pipelines/Plan/Components/QualityProfilePlanComponent.cs:174-193`) — explicit `score` → `score_set` lookup → `DefaultScore` from `trash_scores.default`.

### E.4 qBittorrent INI key shape

*Establishes*: `[BitTorrent]` + `Session\X` is the exact on-disk shape for those three settings.

*Does not establish*: that the deployed image is 5.x. If it is 4.x the keys differ and the preStart would write dead entries.

```
$ cd /tmp/ai/ini && nix shell nixpkgs#crudini -c sh -c \
  'crudini --set t.conf BitTorrent "Session\DefaultSavePath" /persist/media/downloads/complete; cat t.conf'
[BitTorrent]
Session\DefaultSavePath = /persist/media/downloads/complete
```

### E.5 What remains unproven without the live host

- That the deployed gluetun image is the master build containing `efa03037`. *Inferred* from the journal string `attempt 6/30`, which exists only in that commit — strong, but an inference from a log line.
- The consumer of `127.0.0.1:8889` (DB state).
- The on-disk `qBittorrent.conf` version and current path values.
- That anomaly A's fix restores soularr→Lidarr (needs the route + firewall both live).
- Any Sonarr-side recyclarr behaviour.
- Prowlarr/arr proxy settings.

Each is covered by a listed post-deploy probe; none should be described as verified before those run.
