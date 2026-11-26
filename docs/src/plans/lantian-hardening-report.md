# Lantian "Hardening NixOS after I got hacked" vs this fleet

## Status: DRAFT — report only, no configuration changed; line references from the 2026-11-26 tree

This report rewrites [Hardening NixOS after I got hacked](https://lantian.pub/en/article/modify-computer/hardening-nixos-after-i-got-hacked.lantian/) section by section against this repository. For each technique the post prescribes it states what the fleet already has (with file:line proof), what is missing, and what the technique would look like in this repo's idioms. Section 8's snippets are **proposals, not applied**.

## 1. The incident in brief

On 2026-10-14 the author found `python3 -` burning CPU on a server, traced it to 434 successful SSH logins from an unknown IP using their everyday key, and discovered the attacker had hopped a mesh VPN to 12 hosts. The entry path was never identified, so the response was to **assume any exposed service can be RCE'd at any time** and to contain the blast radius: full systemd hardening on every unit, enforced by assertions, plus per-service filesystem confinement so a compromised process sees only its own files. The post closes with defense-in-depth advice: VPN-only access where possible, layered containment, and off-host logs.

## 2. Preventing privilege gain

The post's first layer: run services unprivileged, then `NoNewPrivileges=yes`, `CapabilityBoundingSet=`, `AmbientCapabilities=` so setuid/capability escalation dies inside the service.

**Ours:**

- The shared baseline in `modules/hardening.nix:40` sets `NoNewPrivileges = true` and `CapabilityBoundingSet = ""`; it is spread into our custom units as `_module.args.systemdHardening` (`modules/common.nix:16`) and verified per unit by the `hardening-baseline` contract (`nix/checks.nix:362`).
- `security.sudo.enable = false` (`modules/common.nix:53`), enforced on every host by the `fleet-baseline` contract (`nix/checks.nix:58`) — there is no setuid sudo for a compromised unit to exploit at all, which removes the exact CVE class the post worries about.

**Gap:** `AmbientCapabilities = ""` is not in the baseline. With `CapabilityBoundingSet` empty and `NoNewPrivileges` set the practical exposure is already near zero (ambient caps cannot exceed the bounding set and no new privs can be gained), but adding the explicit empty key matches the post and costs nothing.

## 3. Preventing arbitrary read/write

The post's second layer: `PrivateDevices`, `PrivateTmp`, `ProtectHome`, `ProtectSystem=strict`, `ProtectProc`, `ProcSubset`, plus explicit `ReadWritePaths`/`StateDirectory`/`RuntimeDirectory` grants.

**Ours:** all present in the baseline except three keys: `ProcSubset = "pid"`, `PrivateMounts = true`, `RemoveIPC = true`. Per-unit exceptions are recorded as `minus` entries with reasons (`modules/hardening.nix:12-37`), e.g. `servarrMinus` drops `ProtectSystem` because the \*arr stack writes `/persist/media`.

**Also missing vs the post:** `SystemCallErrorNumber = "EPERM"` — we set it only per-unit (`docs/service.nix:19`) instead of in the baseline. Without it a blocked syscall kills the process with no log line, which is the post's debugging complaint. Belongs in the baseline.

## 4. Preventing obscure features

The post's third layer: `LockPersonality`, `MemoryDenyWriteExecute`, `RestrictNamespaces`/`Realtime`/`SUIDSGID`, `SystemCallArchitectures=native`, `SystemCallFilter`. **Ours:** all present in the baseline (`modules/hardening.nix:53-68`), with JIT-driven exceptions (Node services) documented via `minus`. This section is fully covered.

## 5. Hardening every service via assertions

The post iterates **all** of `config.systemd.services` and fails the build unless every non-exempt unit carries every hardening key (exemptions: templates, oneshot/dbus types, `systemd-*`, `docker-*`/`podman-*`, plus a hand-maintained core list).

**Ours:** the `hardening-baseline` contract (`nix/checks.nix:362-410`) checks an **opt-in per-host inventory** (`modules/hardening.nix:71-125`) — ~21 custom units across yifuwuqi, yirukou, yitaishi. Upstream-managed units (nginx, postgres, exporters, forgejo) are deliberately out of scope; the contract guards our own attrset spreads, not nixpkgs' choices.

**Honest delta:** a newly added custom unit that never registers in the inventory is unchecked — precisely the post's "you will accidentally miss a service" failure mode. A completeness contract (inventory coverage over every enabled non-template, non-oneshot unit on the three server hosts, with a curated upstream allowlist) would close it; the allowlist is derivable from the evaluated unit list per host.

## 6. Filesystem confinement (`RootDirectory` chroot) — the big absence

The post's headline second half: even fully hardened, a service can still *read* the whole filesystem — scan `/nix/store` for a compiler, read other services' files, harvest world-readable secrets. The fix is per-service confinement: `RootDirectory=/run/confinement/%n` with only the unit's store closure plus explicit binds mounted in. nixpkgs ships this as `systemd.services.<name>.confinement` (`nixos/modules/security/systemd-confinement.nix`; already in the pinned input's `module-list.nix`, no import needed). It sets `ReadOnlyPaths=+/`, `RuntimeDirectory=confinement/%n`, `RootDirectory=/run/confinement/%n`, `PrivateMounts`, `PrivateUsers`, `MountAPIVFS` (private /dev, /proc, /sys, /tmp), and bind-mounts the closure of the unit's `Exec*` paths (`fullUnit = true` covers the whole serialized unit).

**Ours: zero.** No unit anywhere in the repo uses `confinement`.

What adopting it here would involve, per service:

- **State is automatic**: `StateDirectory`/`CacheDirectory`/`LogsDirectory`/`ConfigurationDirectory`/`RuntimeDirectory` are bind-mounted into the chroot by systemd. Units that hand-roll state paths (e.g. the arr stack's `/persist/media`) need explicit `BindPaths`.
- **Secrets**: sops-nix defaults land at `/run/secrets/…` (e.g. `modules/services/authelia.nix:56`); the chroot has no `/run`, so each confined unit needs its secret files bound read-only.
- **/etc**: nothing is mounted; most services need at least `passwd`/`group`/`nsswitch.conf`/`resolv.conf`/`hosts`/`ssl/certs` bound in. A small shared helper (the post author built `lantian.harden.*` for exactly this) would keep per-service config thin.
- **Poor candidates, matching the post's own exemption list:** `podman`/`docker-*` units (the container runtime needs namespaces and real /dev — already `exempt` in `modules/hardening.nix:110`), and the Vulkan GPU units `llama-cpp`/`sd-cpp` which already minus `PrivateDevices` for the DRM render node (`modules/hardening.nix:27-30`); `chroot` + `PrivateUsers` + DRM is untested territory and a reasonable `confine = false` with a recorded reason.
- **Highest-value first:** nginx. Two units serve traffic today — the WAN edge on yirukou (`modules/services/nginx-proxy.nix:102`, the TLS terminator for every vhost) and the LAN ingress on yifuwuqi (`modules/services/local-ingress.nix:17`). Confining the edge unit would need the acme cert dirs (`/var/lib/acme`), log dirs, and `resolv.conf` bound in.

## 7. What this fleet already does beyond the post

- **SSH containment** (`modules/services/ssh/default.nix`, enforced by `nix/checks.nix:65-108`): password auth off globally; `nix-builder` is ForceCommand-ed to `nix-daemon --stdio` with all forwarding off; the `ai` user runs a gated `ai-gate` wrapper, key-only; root login restricted to Tailscale addresses; host keys pinned and refusal to auto-generate (`modules/services/ssh/default.nix:44-50`). This directly addresses the post's initial-access vector (stolen key + interactive login) better than the post's own setup.
- **Network exposure**: yirukou's WAN interfaces allow UDP 51820 only (`edge-no-tcp` contract, `nix/checks.nix:260-295`); every nginx location passes Authelia (`auth-gate`, `nix/checks.nix:177-239`) plus a LAN allowlist (`proxy-allowlist`, `nix/checks.nix:139-170`).
- **Containers**: one pinned UID/GID per OCI container, no sharing (`container-identity`, `nix/checks.nix:304-352`).
- **Observability**: central Loki with vector/promtail shipping, a security-monitor module, and fail2ban (`hosts/yifuwuqi/services.nix:91`) — matching the post's "ship logs somewhere the attacker can't reach" advice.

## 8. Gap summary

| #   | Post prescribes                                    | Our state                               | Proposal (not applied)                                                                                                                                 |
| --- | -------------------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | `AmbientCapabilities = ""`                         | absent from baseline                    | add to `modules/hardening.nix` baseline; contract `minus` covers any unit that objects                                                                 |
| 2   | `ProcSubset = "pid"`, `PrivateMounts`, `RemoveIPC` | absent                                  | same — add to baseline                                                                                                                                 |
| 3   | `SystemCallErrorNumber = "EPERM"`                  | per-unit only (`docs/service.nix:19`)   | move into baseline                                                                                                                                     |
| 4   | assert over **all** services                       | opt-in inventory (`nix/checks.nix:362`) | completeness contract: no enabled non-exempt unit outside inventory + upstream allowlist                                                               |
| 5   | confinement for every exposed service              | none repo-wide                          | staged: nginx edge first, then yifuwuqi public stack; helper module for /etc + `/run/secrets` binds; explicit `confine = false` reasons for podman/GPU |
| 6   | no duplicate `BindPaths`                           | unchecked                               | one assertion in the completeness contract                                                                                                             |

## 9. Non-config takeaways

- **VPN-only exposure** — done: management plane is Tailscale-only; WAN edge is one UDP port.
- **Off-host logs** — done in spirit: central Loki on yifuwuqi; a compromised edge host could still reach it, which the post would flag as a remaining single-site risk.
- **Credential rotation** — the post rotated a 10-year-old SSH key; our host keys are pinned and per-user keys are scoped (`ai` vs `nix-builder` vs human users), which limits a single-key compromise's reach.
- **Assume breach** — the confinement gap in row 5 of the table is the fleet's largest remaining distance from the post's model.
