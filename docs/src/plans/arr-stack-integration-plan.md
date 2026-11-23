# Arr Stack Integration Plan

Status: implemented; deployed to yifuwuqi 2026-11-23 19:34. Gate probes pass — 6× active, `Restart=always`, `adding route for 10.42.0.2/32`, soularr reaches Lidarr and completes downloads (anomaly A closed live). Remaining: manual Proton key regen (unblocks the anomaly-C probe), a root read of the live qBittorrent.conf, a live recyclarr run, and the new soularr import-permission finding under "Verification". Delete this file and the companion [report](arr-stack-integration-report.md) once those pass.

## Objective

Fix the three live failures found in the arr stack review, make the cheaply-declarable manual bootstrap steps declarative, register the one port that sits outside the address registry, and correct the documentation claims that are false today.

## Current state

- **A — soularr cannot reach Lidarr.** Gluetun's netns routes everything except the podman bridge subnet (`10.88.0.0/16`) into the tunnel, so `10.42.0.2:24686` never reaches the host. The host firewall rule for container→Lidarr is necessary but not sufficient; there is no route and no netns OUTPUT accept. Every soularr cycle times out (`Timeout occurred while connecting to API`) and the Soulseek→Lidarr pipeline delivers nothing.
- **B — Proton port forwarding is down.** The WireGuard key was generated without NAT-PMP, so PMP RPC is refused. Worse, the 30-attempt give-up path exits gluetun with status **0**, which `Restart=on-failure` (`oci-containers.nix:564`) ignores; `bindsTo`/`partOf` then stop qbittorrent, slskd, soularr, torrent-indexer and flaresolverr permanently, and only gluetun's `ExecStartPost` ever re-queues them.
- **C — the PF up-command is malformed.** It uses shell `$1` and escaped quotes, but gluetun substitutes `{{PORT}}` and execs without a shell. Proven by running gluetun's own `split` on the deployed string: `argv[4] = "json={\"listen_port\":$1,\"upnp\":false,\"random_port\":false}"` — literal `$1`, invalid JSON. Fixing B alone would still leave `listen_port` unset. No down-command exists either, which upstream requires so the port is re-set after a reconnect.
- **Manual steps.** qBittorrent save paths and the pt-BR custom format are cheaply declarable. Root folders, download-client entries, and Prowlarr indexers/integrations are SQLite-backed in each arr app with no env-var mechanism. Initial auth is inherent. The `music` category needs no provisioning at all — Radarr/Lidarr create it on client save.
- **Registry gap.** `127.0.0.1:8889:8888` (gluetun HTTP proxy) is the one stack port outside `modules/addresses/hosts.nix`. It is **not** dead config: plausible consumers are DB state (Prowlarr "Http" indexer proxy, per-app `ProxyEnabled`), invisible to text search. Since `f7fbaad` it is loopback-only, so a consumer pointing at the LAN or tailnet address has been failing for two weeks.

## Evidence basis

Claims below are marked by how they were established. Per `fp-check`, generated/compiled/example-tested/verified are distinct and are not used interchangeably. Appendix references (E.1–E.5) resolve in the companion [report](arr-stack-integration-report.md).

| Claim                                                                        | Level                                  | Evidence                                                                                                               |
| ---------------------------------------------------------------------------- | -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| C: deployed up-command yields literal `$1`                                   | **example-tested** (real code, 1 case) | gluetun `split` compiled verbatim, run on the deployed string — report appendix E.1                                    |
| C: `/bin/sh -c` + `{{PORT}}` yields valid JSON                               | **example-tested** (1 port/intf)       | same script on the proposed string, then executed with a stub `wget` — E.1                                             |
| Documented pt-BR regex misses real shapes                                    | **example-tested** (9+9 corpus)        | Go `regexp`, 3 misses / 0 false positives — E.2                                                                        |
| Replacement regex is sound                                                   | **example-tested**, not proven         | 0 misses / 0 false positives on the same corpus — E.2                                                                  |
| Recyclarr can consume a local provider and score from `trash_scores.default` | **example-tested** (stub API)          | real `recyclarr 8.8.1 sync radarr` → POST `/customformat`, PUT profile with `score: 50` — E.3                          |
| qBittorrent key shape `[BitTorrent] Session\X`                               | **example-tested**                     | `session.h:393` + crudini round trip — E.4                                                                             |
| A: missing route is the cause                                                | **source-verified**, live unconfirmed  | `main.go:322-325`, `routing/outbound.go:12-13`, `vpn/wireguard.go:69`; needs the post-deploy `ip route show table 199` |
| B: exit 0 → no restart → permanent cascade                                   | **source-verified**, live unconfirmed  | `retry.go:28`, `main.go:530-531`, `oci-containers.nix:564`                                                             |
| Deployed image is gluetun master                                             | **inferred**                           | journal `attempt 6/30` exists only in `efa03037`, which is in no release tag                                           |
| 8889 consumer identity                                                       | **unknown**                            | DB state; no probe yet                                                                                                 |
| Deployed qBittorrent major version                                           | **unknown**                            | image tag is `:latest`; read the conf first                                                                            |

## Decisions

- `FIREWALL_OUTBOUND_SUBNETS` derives from the registry (`addrs.network.lan.ipv4.host`) and is narrowed to `/32`; a broad `10.x` entry can overlap the WireGuard tunnel range and break Proton NAT-PMP.
- `Restart = lib.mkForce "always"` on `podman-gluetun`. The narrower `RestartForceExitStatus = [ 0 ]` is equivalent here; `always` is chosen because this unit is a long-running daemon with no clean-exit use, and systemd's start rate limit still contains a genuine crash loop.
- Replace the up-command with the `{{PORT}}`/`{{VPN_INTERFACE}}` form run through `/bin/sh -c`, and add the down-command.
- pt-BR custom format ships as a **local `custom-formats` resource provider** (`settings.yml` + one JSON). Recyclarr's `custom_formats` is trash-id-only, so no guide CF can express the regex. The score lives once in the JSON as `trash_scores.default`, which recyclarr reads as `DefaultScore`.
- Keep the gluetun HTTP proxy, register it in the address registry, and leave it unauthenticated: the loopback-only publish is the mitigation. No `HTTPPROXY_USER`/`PASSWORD` in this change set.
- No category provisioning write; no API-provisioning oneshots for root folders, download clients, or Prowlarr integrations.
- Not in this change set: pinning the gluetun image, tuning the pt-BR score against `min_format_score`.

## Phases

### 1. Anomaly A — gluetun outbound routing

`modules/services/qbittorrent-vpn.nix`, gluetun `environment`:

```nix
# Destination-scoped escape from the tunnel: soularr (shared netns) calls
# Lidarr on the host LAN address. Narrow /32 or the rule overlaps the
# WireGuard tunnel range and breaks Proton NAT-PMP.
FIREWALL_OUTBOUND_SUBNETS = "${addrs.network.lan.ipv4.host}/32";
```

Residual risk: gluetun installs a destination-wide OUTPUT accept inside the netns, so every container sharing the namespace can reach any port on `10.42.0.2`. The host's `extraInputRules` remains the port-level gate (`24686`, `24888`, DNS) and must not be widened.

### 2. Anomaly B mitigation — survive the PF give-up

Same file, `services."podman-gluetun".serviceConfig`:

```nix
# A port-forwarding give-up exits gluetun with status 0, which
# Restart=on-failure ignores; restart so a new session picks another server.
Restart = lib.mkForce "always";
```

### 3. Anomaly C — the up/down commands

Same file. `{{PORT}}` and `{{VPN_INTERFACE}}` both shipped in v3.41.0 (`fcdba0a3`, `a35c994b`; `git tag --contains` → `v3.41.0`).

```nix
VPN_PORT_FORWARDING_UP_COMMAND = "/bin/sh -c 'wget -O- -nv --retry-connrefused --post-data \"json={\\\"listen_port\\\":{{PORT}},\\\"current_network_interface\\\":\\\"{{VPN_INTERFACE}}\\\",\\\"random_port\\\":false,\\\"upnp\\\":false}\" http://127.0.0.1:8080/api/v2/app/setPreferences'";
VPN_PORT_FORWARDING_DOWN_COMMAND = "/bin/sh -c 'wget -O- -nv --retry-connrefused --post-data \"json={\\\"listen_port\\\":0,\\\"current_network_interface\\\":\\\"lo\\\"}\" http://127.0.0.1:8080/api/v2/app/setPreferences'";
```

This exact escaping has already been exercised: gluetun's own split produces `argv = ["/bin/sh", "-c", "<payload>"]` and executing the payload with a stub `wget` yields `json={"listen_port":51413,"current_network_interface":"tun0",...}`. Re-run that check after any edit to these strings — it is cheap and it is the only thing standing between this phase and another silent no-op.

The in-netns qBittorrent Web UI on `127.0.0.1:8080` with `WebUI\LocalHostAuth=false` is already enforced by the preStart, which is upstream's stated prerequisite.

### 4. qBittorrent save paths

Same file, in the existing crudini block:

```bash
${pkgs.crudini}/bin/crudini --set ${conf} BitTorrent 'Session\DefaultSavePath'  /persist/media/downloads/complete
${pkgs.crudini}/bin/crudini --set ${conf} BitTorrent 'Session\TempPathEnabled'  true
${pkgs.crudini}/bin/crudini --set ${conf} BitTorrent 'Session\TempPath'         /persist/media/downloads/incomplete
```

Read the live `qBittorrent.conf` first and confirm the deployed client is 5.x; key names were taken from `v5_0_x` source (`session.h:393` defines the `BitTorrent/Session/` prefix, `sessionimpl.cpp:503-505` the three keys), and a 4.x image uses different keys. The crudini round trip on a scratch file has been executed and emits the expected lines. Enforcement overrides manual UI edits of these two paths; `categories.json` is untouched, so only the default path and new torrents move.

### 5. pt-BR custom format

`modules/services/arr/default.nix`, using the repo's format generators (as in `modules/services/ai/sillytavern.nix`):

```nix
yamlFormat = pkgs.formats.yaml { };
jsonFormat = pkgs.formats.json { };

ptBrFormat = jsonFormat.generate "ptbr-dubbed-dual-audio.json" {
  trash_id = "ptbr-dubbed-dual-audio";
  # Single home for the score: recyclarr applies DefaultScore to every profile
  # that does not override it, so no number appears twice.
  trash_scores.default = 50;
  name = "pt-BR Dubbed / Dual Audio";
  specifications = [{
    name = "pt-BR";
    implementation = "ReleaseTitleSpecification";
    negate = false;
    required = false;
    # NOT the pattern in arr-stack.md: that one misses "Dual-Áudio",
    # "DUALÁUDIO" and "_DUBLADO_" (measured, 3 of 9 positives). This one
    # matches 9/9 positives and rejects 9/9 negatives in the same corpus,
    # including the trap "dualpixel".
    fields.value = "(?i)(?:^|[^a-z0-9])(dublado|dual[\\W_]?(?:[aá]udio)|pt[\\W_]?br)(?:$|[^a-z0-9])";
  }];
};

recyclarrSettings = yamlFormat.generate "recyclarr-settings.yml" {
  resource_providers = [
    { name = "ptbr-radarr"; type = "custom-formats"; service = "radarr"; path = "custom-formats"; }
    { name = "ptbr-sonarr"; type = "custom-formats"; service = "sonarr"; path = "custom-formats"; }
  ];
};
```

The nixpkgs module generates only `config.yml` (`misc/recyclarr.nix:13,112`) and has no `settings.yml` option, so install both files from the unit:

```nix
systemd.services.recyclarr.preStart = lib.mkAfter ''
  install -Dm644 ${recyclarrSettings} /var/lib/recyclarr/settings.yml
  install -Dm644 ${ptBrFormat} /var/lib/recyclarr/custom-formats/ptbr-dubbed-dual-audio.json
'';
```

`StateDirectory = "recyclarr"` and `RECYCLARR_CONFIG_DIR=/var/lib/recyclarr` already come from the module. Adding `resource_providers` preserves the implicit official providers (they are injected first unless `replace_default`), so guide CFs still resolve.

Both radarr and sonarr instances gain, with no `score` (the JSON carries it — `DetermineScore` precedence is explicit `score` > `score_set` > `trash_scores.default`):

```nix
custom_formats = [{
  trash_ids = [ "ptbr-dubbed-dual-audio" ];
  assign_scores_to = [ { name = "All-in-One"; } ];
}];
```

This configuration has been run end-to-end against a stub Radarr with the real `recyclarr 8.8.1`: it created the CF and wrote `"score": 50` into the profile's `formatItems`. Sonarr was only checked with `list custom-formats sonarr`, not a sync.

### 6. Registry and cleanup

- `modules/addresses/hosts.nix`: add `gluetun = { port = 8889; internalPort = 8888; };`, and switch the publish in `qbittorrent-vpn.nix` to `"127.0.0.1:${toString addrs.services.gluetun.port}:${toString addrs.services.gluetun.internalPort}"`. Safe to add: the registry enumerators skip entries without a `domain` or `group` — `homepage.nix` filters on `group`, `modules/desktop/web-apps.nix` on `? name`, `docs/generate.nix` renders `—`. It does not become a vhost; `proxy-vhosts.nix` keeps its own explicit list.
- Delete `recyclarr.serviceConfig.EnvironmentFile = envFile;` in `modules/services/arr/default.nix` — recyclarr reads its keys through `LoadCredential` and never reads the servarr env vars.
- Fix the stale comment in `modules/services/slskd.nix` around the `[Lidarr]` block: reachability comes from `FIREWALL_OUTBOUND_SUBNETS` plus the firewall rule, not the rule alone.

### 7. Docs

`docs/src/services/arr-stack.md`:

- §3: save/incomplete paths are enforced by the unit; only the forwarded-port check stays manual.
- §4: drop "must exist in qBittorrent" — the arr app creates the category on client save/test.
- §6: scope is radarr+sonarr quality definitions, `All-in-One` profiles, and the pt-BR CF; keys arrive via systemd credentials, not env vars; schedule is the maintenance slot `*-*-* 04:15:00` + 5m jitter; Lidarr/Readarr are unsupported by recyclarr.
- §7: the routing note — soularr reaches Lidarr only because the gluetun namespace is allowed to route to the host LAN address.
- §8: custom formats are declarative via a local provider; keep the Prowlarr indexer step.
- Proxy: `127.0.0.1:8889` (host) → `:8888` (netns), unauthenticated, loopback-only; the LAN and tailnet addresses no longer answer.
- Jellyfin: the port rewrite only patches an existing `network.xml`, so a genuinely first boot needs one restart.

Regenerate `docs/src/generated/services.md` (`nix build .#docs-generated --out-link /tmp/docs-frag && install -m0644 /tmp/docs-frag/*.md docs/src/generated/`); the `docs-registry-sync` check diffs it byte-for-byte.

## Verification

Local, non-destructive (all run; results as of implementation):

- `nix eval --json ...containers.gluetun.environment` → `FIREWALL_OUTBOUND_SUBNETS = "10.42.0.2/32"`. ✔
- `...containers.gluetun.ports` still publishes `127.0.0.1:8889:8888`. ✔
- **Up-command round trip.** Evaluated both commands, ran them through gluetun's verbatim `split` (`/tmp/ai/splitproof`), substituted `{{PORT}}=51413`/`{{VPN_INTERFACE}}=tun0`, then executed the resulting payload with a stub `wget`: argv carries `json={"current_network_interface":"tun0","listen_port":51413,...}`, valid JSON, `listen_port` numeric. ✔ (example test, one port/interface)
- `nix eval --raw ...podman-qbittorrent.preStart | rg 'DefaultSavePath|TempPath'` → three crudini lines. ✔
- `nix eval --raw ...recyclarr.preStart | rg 'settings.yml|custom-formats'` → both install lines. ✔
- `nix eval --json ...recyclarr.configuration` → `custom_formats` present, no `score`. ✔
- Real `recyclarr 8.8.1 sync --config <config.yml>` (the module's exact invocation) against the stub Radarr on port 24879, using the **generated** `settings.yml` + JSON: `Created 1 New Custom Formats`, profile `formatItems` carry `"score": 50`. ✔ (radarr only; sonarr unexercised)
- `treefmt --fail-on-change`, `deadnix`, `statix`, `nix flake check --no-build` clean; `checks.{contracts,docs-registry-sync,docs}` build. ✔
- `docs/src/generated/services.md` regenerated; the `gluetun` row is now present. ✔

Not verified locally:

- The deployed qBittorrent conf. `docker.io/linuxserver/qbittorrent` version still unread, so the `Session\*` keys are proven against 5.x source only. **Read the live conf before trusting the paths.**
- Sonarr-side recyclarr behaviour.
- That the `wget` shipped in the gluetun image accepts the up/down-command flags (`-nv`, `--retry-connrefused`). E.1 proved argv shape with a stub `wget`, not flag acceptance (busybox `wget` rejects both), and the old command never fired live, so there is no runtime evidence either. The anomaly-C `journalctl -g 'up command'` probe catches a rejection.
- That the running `:latest` gluetun build accepts `VPN_PORT_FORWARDING_DOWN_COMMAND`. Gluetun fails fast on unknown env vars, so `systemctl is-active podman-gluetun` right after switch settles it.

Live, after `ci/deploy.sh switch yifuwuqi` (deploy done 2026-11-23 19:34; probes below are run by a host whose AI key yifuwuqi authorizes — yitaishi's is not provisioned, and the gate has no `podman exec`, so the netns and conf probes need root):

Results (via the gate, ~19:53): 6× `active`; `Restart=always`; journal shows `[routing] adding route for 10.42.0.2/32` plus `setting allowed subnets`; no more soularr `Timeout occurred` — it completes downloads now (anomaly A closed live). `ip route show table 199` on the host errors with `FIB table does not exist` — the rule lives in the netns; the journal line is the authoritative confirmation. PMP is still refused (`attempt 7/30` at 19:47) — expected until the Proton key regen, so anomaly C stays unprobed behind it. recyclarr last ran 04:18 (pre-change) and next fires 04:17:58; `sudo systemctl start recyclarr.service` verifies the pt-BR sync sooner.

**New finding the A-fix surfaced — soularr import `PermissionError`s.** With routing fixed, soularr's move-to-temp step now runs and partially fails: `os.rename`/`os.unlink` get EACCES inside slskd-created album dirs (e.g. `/downloads/不出来 disc 01/`), while copies into soularr-created target dirs succeed. Hypothesis (unverified — the gate denies `/persist/media/**`, so this needs root): those source dirs lack group-write; umask cannot add bits, so an explicit restrictive mkdir in slskd defeats `--umask=0002` even though both containers already share the `media` group. One root look settles it: `sudo ls -lan /persist/media/downloads/soulseek/` plus one failing subdir. Fix is a separate change set from this one.

- `ai-ssh yifuwuqi journalctl -u podman-soularr -n 30` shows no `Timeout occurred while connecting to API`. (gate-allowed)
- `ai-ssh yifuwuqi journalctl -u podman-gluetun -g 'setting allowed subnets|adding route for' -n 30` shows the outbound subnet accepted. (gate-allowed)
- `ai-ssh yifuwuqi systemctl is-active podman-gluetun podman-qbittorrent podman-slskd podman-soularr podman-torrent-indexer podman-flaresolverr` → 6× `active`. (gate-allowed)
- `ai-ssh yifuwuqi systemctl show podman-gluetun -p Restart` → `Restart=always`. (gate-allowed)
- As root on yifuwuqi: `cat /var/lib/container-volumes/qbittorrent/qBittorrent/qBittorrent.conf` carries the three `Session\*` keys. (The gate denies this path — tried 2026-11-23, `denied: path outside allowlist` — so this is a root probe; confirms the 5.x key shape against the real image.)
- `ai-ssh yifuwuqi journalctl -u recyclarr -n 40` after a manual `systemctl start recyclarr.service` shows radarr/sonarr processing and the pt-BR format created/scored. (gate-allowed)
- `ai-ssh yifuwuqi ip route show table 199` and `ip rule show` → the `10.42.0.2` escape route and priority 99. (gate-allowed; reads the host's view, not the netns, so treat as indirect)
- As a normal user on yifuwuqi: `podman exec gluetun ip route show table 199` (needs root, so run manually).
- Anomaly C only becomes checkable once the Proton key is regenerated: `journalctl -u podman-gluetun -g 'up command|listen_port'` shows a non-empty `up command:` result and qBittorrent's `listen_port` equals `/tmp/gluetun/forwarded_port`.
- `systemctl is-active podman-gluetun` with `Restart=always` and the five consumers back after a simulated PF give-up (manual, needs root).

## Rollout order

1. Phases 1–7 are one change set (in the working tree); the deploy bounces gluetun once and re-queues the five consumers.
1. Post-deploy probes above, except the anomaly C line. Run them from a host whose AI key yifuwuqi authorizes, or as `root` on yifuwuqi for the `podman exec` ones.
1. Manual, outside Nix: regenerate the Proton WireGuard key with NAT-PMP, update `services/proton/wireguard_private_key`, redeploy; then run the anomaly C probe. Anomaly C stays unverified until this happens.
1. Once every phase is verified, delete this plan file in the same change set — code and docs become the record.

## Open questions

- Which process consumes `127.0.0.1:8889` — Prowlarr's "Http" indexer proxy, or per-app `ProxyEnabled`? DB state; unverifiable without a live probe. Nothing here depends on the answer, since the proxy is preserved either way. Once known, decide whether to add `HTTPPROXY_USER`/`PASSWORD` as sops secrets.
- Pin the gluetun image (v3.41.4 or later) instead of `:latest`? Anomaly B arrived through an unpinned master build, so the PF code path can change again without a flake update. Pinning trades automatic fixes for a knowable code path.
- Should the pt-BR format also raise `min_format_score` on `All-in-One`? Separate tuning decision, DB-side.
- The replacement regex is example-tested, not proven. If false positives appear in real indexer results, the cheapest tightening is an additional negative specification excluding `legendado` (subtitled) rather than complicating the title regex.

## Out of scope

- API-provisioning oneshots for root folders, download clients, or Prowlarr indexers/integrations.
- Credentials on the gluetun HTTP proxy.
- Migrating the up-command to the multi-port `{{PORTS}}` shape (one forwarded port today).
