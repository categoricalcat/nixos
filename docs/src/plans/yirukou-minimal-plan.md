# Minimal Appliance Profile for yirukou

## Status: IMPLEMENTED AND DEPLOYED — Phases 1–5.3 done; `yirukou` runs `2.1 GiB` (was `4.2 GiB`) with zero failed units. Remaining before retirement: post-reboot console check (phase 4 firmware trim lands on the next boot) and a manual `nix develop` as `yi`.

## Objective

Strip **`yirukou`** (perimeter router, firewall, DNS, reverse proxy, and Tailscale gateway) down to a minimal appliance configuration by removing Home Manager, interactive TUI/AI/developer tooling, `nix-ld`, distributed-build client plumbing, redundant firmware, and default NixOS desktop/doc bloat, while preserving **100% of routing, firewalling, DNS, TLS proxy, SSH/SOPS, and monitoring/security telemetry** (`exporters`, `vector`, `security-monitor`, and `goaccess`).

At the same time, deduplicate shared developer/AI wrappers (`packages/wrappers.nix`) out of `modules/packages/default.nix` so **all dev tooling lives solely in `nix develop` (`nix/devshell.nix`)** and never leaks into appliance system closures.

______________________________________________________________________

## Current state

### Repository-verified

- **`yirukou` imports desktop/workstation shared layers**:
  - `flake.nix` (`mkNixosHost`) unconditionally attaches `home-manager.nixosModules.home-manager` to every NixOS host, and `modules/common.nix` unconditionally sets `home-manager.sharedModules`.
  - `hosts/yirukou/configuration.nix` imports `modules/home-manager.nix` (creating full Home Manager environments for both `yi` and `root`), `modules/packages` (`modules/packages/default.nix`), `modules/distributed-builds.nix`, and `users/users.nix`.
  - `modules/common.nix` unconditionally imports `modules/nix-ld.nix`, `modules/services/ai/opencode.nix`, `modules/services/kmscon.nix`, and `docs/service.nix`.
- **Developer/AI wrappers are duplicated**:
  - `modules/packages/default.nix` imports `packages/wrappers.nix` (`diff-to-commit`, `lock-to-changelog`, `nxd-agent`, `nxd-agy`, `nxd-opencode`, `seenix`) into every host's `environment.systemPackages`, even though `nix/devshell.nix` already provides the exact same `wrappers` set inside `devShells.default` (`nix develop`).
  - `nix/devshell.nix` (`defaultShell`) does not currently include `pkgs.git` (only `sandboxShell` does), relying on `modules/packages/default.nix` for `git`.
- **Shared `users/users.nix` forces workstation defaults onto `yirukou`**:
  - Sets `defaultUserShell = pkgs.zsh`, `programs.zsh.enable = true`, `ZSH_COMPDUMP`, and `pathsToLink = [ "/share/zsh" ]`.
  - Creates `extraUsers.none` (only used by `forgejo-runner.nix` on `yifuwuqi` and `devShells.sandbox`) and `users.nix-builder`.
  - Grants `yi` unused workstation/container groups (`render`, `video`, `dialout`, `networkmanager`, `tss`, `plugdev`, `podman`, `docker`).
  - Installs `nix-sanity`, `gh-backup`, and `ai-ssh` into `environment.systemPackages`.
- **Evaluated `yirukou` closure and live host observations (2026-11-22)**:
  - Live system path `/nix/store/zrsbp70191k9gn295bl4bg8wkiqlv6dy-nixos-system-yirukou-26.11.20261121.2786a2a` measures **4.2 GiB** (`nix path-info -r -S -h`):
    - `home-manager-path` (`yi` + `root`): **1.1 GiB** cumulative closure each, driven by `host.tui = true` (`yazi` **530.9 MiB** closure pulling `ffmpeg-headless`, `btop` overridden with `rocmSupport = true` pulling `rocm-smi-7.2.4` **228.5 MiB** closure on an Intel router, `lazygit`, `gitui`, `delta`, `zellij`, `tmux`, `atuin`, `mcfly`, `broot`, `bottom`, `scmpuff`, `fzf`, `zoxide`, `direnv`, `nix-direnv`, `starship`), `fastfetch` (**430.1 MiB** closure), `gh` + extensions, `kitty.terminfo`, `fontconfig`, `shared-mime-info` (**78.4 MiB** closure), `man-db` (**77.0 MiB** closure), `ssh-agent` user service, and `users/home/ai-policies.nix` (~65 generated rule/skill files under `.agents/`, `.claude/`, `.cursor/`, `.gemini/`, `.opencode/`, and `.config/zed/`).
    - `system-path`: **1.4 GiB** cumulative closure, including `git` (**386.0 MiB** closure, `git-doc` **15.7 MiB**), `nixos-rebuild-ng` (**350.6 MiB** closure), `command-not-found` (**134.2 MiB** closure), `man-db` (**77.0 MiB**), `nano` (**53.5 MiB** closure, **2.6 MiB** self), `zsh` (**49.5 MiB** closure, **7.4 MiB** self), `nixos-manual-html` (**29.7 MiB**), `kea-3.2.1-doc` (**24.5 MiB**), `packages/wrappers.nix`, `nh`, `stow`, `p7zip`, `zip`, `unzip`, `sops`, `ssh-to-age`, `bat`, `fd`, `ripgrep`, `ncdu`, `pik`, `tree`, and `wget`.
    - `linux-firmware-20261019-zstd`: **825.2 MiB** self (**852.2 MiB** with `firmware` wrapper), pulled solely by `hardware.enableRedistributableFirmware = lib.mkDefault true` from nixpkgs's `installer/scan/not-detected.nix` imported in `hosts/yirukou/hardware.nix`.
    - Monitoring & security telemetry (kept): `vulnix-1.12.5` (**502.1 MiB** closure) / `unit-security-audit-cve.service` (**685.6 MiB** closure, pulling `nix-2.35.6-dev` **323.2 MiB**), `vector-0.62.0` (**141.7 MiB** self / **218.4 MiB** closure), `goaccess-1.12` (**2.8 MiB** self / **52.1 MiB** closure), and the 10 Prometheus exporters (`node`, `smokeping`, `blackbox`, `systemd`, `process`, `smartctl`, `nginx`, `adguard`, `unbound`, `redis`).
  - Live `yirukou` kernel boot log (`ai-ssh yirukou journalctl -b -k` and `/proc/modules`):
    - All 6 NICs (`enp2s0`..`enp7s0`) use `igc` (Intel 2.5GbE), which requires no external firmware blobs.
    - Storage uses `nvme` and `ahci`; CPU microcode updates early via `microcode-intel` (`0x426 -> 0x43b`).
    - `i915` loads `adlp_dmc.bin`, `adlp_guc_70.bin`, and `tgl_huc.bin` on the unused integrated GPU; `snd_sof_pci_intel_tgl` and `cfg80211` also load despite `modules/server-settings.nix` blacklisting `snd`/`snd_hda_*`.
    - `systemd-resolved` receives Tailscale DNS updates (`100.100.100.100`, `fd7a:115c:a1e0::53`) over DBus from `tailscaled` (`--accept-dns=true`).
    - `yirukou` currently boots on persistent Ext4 (`nvme0n1p2`, `7.85 GiB` RAM, `6.46 GiB` available).

______________________________________________________________________

## Decisions

1. **Scope of `nix develop` vs host profiles**:
   - Remove `packages/wrappers.nix` (`diff-to-commit`, `lock-to-changelog`, `nxd-agent`, `nxd-agy`, `nxd-opencode`, `seenix`) from `modules/packages/default.nix` so they live exclusively in `nix/devshell.nix` (`nix develop`), avoiding duplicate installation in system profiles.
   - Keep desktop/workstation developer profiles (`modules/packages/dev.nix`, `host.developer`, `users/home/yijia.nix`) intact on `yitaishi`, `yixiaoqing`, `yifuwuqi`, and `yichuang`.
   - Strip all dev, TUI, AI, and Home Manager tooling from `yirukou`; whenever ad-hoc dev or repo tools are needed on `yirukou`, enter `nix develop` (pulling pre-built closures from Attic / `cache.nixos.org`). Add `pkgs.git` to `nix/devshell.nix`'s `defaultShell` so `nix develop` remains self-contained without host `git`.
1. **Drop Home Manager on `yirukou`; keep minimal `yi` + `root` + `ai` with `bash`**:
   - Remove `home-manager` from `yirukou` completely (no `yi` or `root` HM profiles, no `tui.nix`, no `ai-policies.nix`, no `fastfetch`, no `git.nix`, no `ssh-agent` user service).
   - Keep the normal `yi` login account (with its existing `secrets/keys.nix` SSH access from `yifuwuqi`) alongside `root` and read-only `ai` (`ai-ssh`), switching `root` and `yi` to `bash` (`users.defaultUserShell = pkgs.bashInteractive`, `programs.zsh.enable = false`).
   - Keep `modules/services/ssh`'s `nix-builder` `Match` block compatible with `nix/checks.nix` (`sshd-hardening` contract), or gate both the `nix-builder` user/Match block and the contract on `nixBuild.remoteBuilder || forgejo-runner` so `nix flake check --no-build` stays green.
1. **Preserve 100% of monitoring, security telemetry, and core router contracts**:
   - Monitoring is essential on the perimeter gateway: keep `modules/services/monitoring/exporters.nix` (all 10 exporters), `modules/services/monitoring/promtail.nix` (Vector), `modules/services/monitoring/security-monitor` (both `fastAudit` and `cveScan`), and `hosts/yirukou/goaccess.nix` (plus `goaccess.aset.love` and `modules/hardening.nix` entries) completely intact.
   - Keep `modules/services/ssh`, `tailscale`, `adguardhome`, `unbound`, `valkey`, `nginx-proxy`, `chrony`, `services.resolved` (for Tailscale DNS), `secrets/sops.nix`, `modules/nix-settings.nix` (Lix + Attic cache client + `/etc/nix/inputs`), `modules/packages/network.nix`, `programs.mtr`, and `programs.trippy`.
   - Keep `curl`, `dig` (`bind.dnsutils`), and `jq` available in `yirukou`'s minimal `environment.systemPackages` so offline/broken-WAN router triage works without `nix develop` (`jq` and `curl` are already in the runtime closure via `security-audit-cve` and `nix`).
   - Replace `nh.clean` with native `nix.gc` (using `modules/maintenance.nix`'s `slots.nixGc` schedule) so `/nix/store` still collects garbage automatically after `nh` is removed.
1. **Trim NixOS defaults, `nix-ld`, `distributed-builds`, and unused `linux-firmware`**:
   - Disable `programs.nix-ld`, `programs.command-not-found`, `documentation.*` (`enable`, `man`, `info`, `doc`, `nixos`), `system.disableInstallerTools` (keeping `nixos-version` if desired; `nixos-rebuild` lives in `nix develop` and deploys run from `yifuwuqi`/CI), `xdg.{mime,icons,autostart,menus,portal}`, and `fonts.fontconfig`. Keep `programs.nano` (emergency console editor).
   - Remove `modules/distributed-builds.nix` from `yirukou` and set `nixBuild.useRemoteBuilders = false` / `remoteBuilder = false` for `yirukou` in `modules/addresses/hosts.nix`.
   - Set `hardware.enableRedistributableFirmware = false` and `hardware.wirelessRegulatoryDatabase = false` while keeping `hardware.cpu.intel.updateMicrocode = true` explicit in `hosts/yirukou/hardware.nix`, dropping ~825–852 MiB of unneeded wireless/audio/GPU firmware blobs.

______________________________________________________________________

## Phases

### Phase 1 — Deduplicate Dev Wrappers into `nix develop`

1. **`modules/packages/default.nix`**:
   - Remove `wrappers = import ../../packages/wrappers.nix { inherit pkgs; };` and `++ (builtins.attrValues wrappers)` from `environment.systemPackages`.
1. **`nix/devshell.nix`**:
   - Add `pkgs.git` and `pkgs.neovim` to `defaultShell.packages` so `nix develop` has `git` and `$EDITOR` (`nvim`) available even on minimal hosts without system-wide dev packages.
   - Evaluate `users/home/shell.nix` and `users/programs/git.nix` (`serverMode.developer = false; serverMode.tui = true;`) as a Single Source of Truth so both `devShells.default` and `devShells.sandbox` export `ZDOTDIR`, `STARSHIP_CONFIG`, fallback `XDG_CONFIG_DIRS`/`DIRENV_CONFIG`/`ZELLIJ_CONFIG_DIR`/`GIT_CONFIG_GLOBAL`, zsh completions/site-functions, `EDITOR`/`VISUAL`, and `FZF_*` for any user (`yi`, `root`, `none`) without making `$XDG_CONFIG_HOME` read-only or breaking `direnv` (`DIRENV_IN_ENVRC`) or `nix develop --command`.
   - Verify `defaultShell.shellHook` handles being entered on a host without a user `~/.zshrc` or outside a `.git` directory cleanly (confirmed: `git-hooks.nix` skips installation when `git rev-parse --git-dir` fails, and `mkShellEnvHook` provides fallback `ZDOTDIR`, `STARSHIP_CONFIG`, `XDG_CONFIG_DIRS`, and `GIT_CONFIG_GLOBAL`).
1. **Docs check**:
   - Audit `docs/src/` for references to `nxd-*` / `seenix` / `diff-to-commit` / `lock-to-changelog` outside `nix develop` and confirm `docs/src/services/nix-build-cache.md` accurately describes them as devshell tools.

### Phase 2 — Parameterize Shared Host Modules Cleanly

1. **`flake.nix` & `modules/home-manager.nix` & `modules/common.nix`**:
   - Move `home-manager.nixosModules.home-manager` out of `mkNixosHost`'s unconditional module list in `flake.nix` into `extraModules` for `yixiaoqing`, `yitaishi`, `yifuwuqi`, and `yichuang` (leaving `yirukou` with `extraModules = [ ]`).
   - Move `home-manager.sharedModules = [ { inherit (config) host serverMode; } ];` out of `modules/common.nix` and propagate `osConfig.host` / `osConfig.serverMode` conditionally inside `modules/home-manager.nix`'s existing `sharedModules` module (preserving standalone `homeConfigurations.yijia` where `osConfig == null`).
   - Confirm `modules/services/ai/opencode.nix` (`config.home-manager.users.yi.programs.opencode.enable or false`) still evaluates cleanly on `yirukou` without `home-manager` imported.
1. **`modules/nix-ld.nix`**:
   - Set `programs.nix-ld.enable = lib.mkDefault true;` and guard `libraries = lib.mkIf config.programs.nix-ld.enable (...)` so setting `programs.nix-ld.enable = false;` on `yirukou` drops `nix-ld` and its C/GLib/NSS/DBus library closure completely.
1. **`users/users.nix`**:
   - Use `lib.mkDefault` on `users.defaultUserShell = pkgs.zsh`, `programs.zsh.enable = true`, `ZSH_COMPDUMP`, and `pathsToLink = [ "/share/zsh" ]` (or guard `ZSH_COMPDUMP`/`pathsToLink` on `config.programs.zsh.enable`).
   - Gate `nix-sanity`, `gh-backup`, and `ai-ssh` in `environment.systemPackages` on `config.host.developer` (all hosts that run `nix-sanity`/`gh-backup` or initiate `ai-ssh` have `host.developer = true`).
   - Gate `extraUsers.none` / `groups.none` on `config.host.developer || config.services.forgejo-runner.instances != { }`.
   - Scope `users.users.yi.extraGroups` to capabilities actually present on the host (always `"systemd-journal"`; gate `"podman"`, `"docker"`, `"networkmanager"`, and desktop/hardware groups `"render"`, `"video"`, `"dialout"`, `"tss"`, `"plugdev"`).
   - Gate `users.users.nix-builder` (or keep `nix-builder` locked system user aligned with `modules/services/ssh/default.nix` and `nix/checks.nix`'s `sshd-hardening` contract; see Open Questions).

### Phase 3 — Strip `yirukou` to a Minimal Appliance Configuration

1. **`hosts/yirukou/configuration.nix`**:
   - Remove `mkHome` import and `home-manager = mkHome { ... };`.
   - Remove `../../modules/packages` and `../../modules/distributed-builds.nix`.
   - Set `nixBuild.enable = false;` (or `useRemoteBuilders = false;`) for `yirukou` in `modules/addresses/hosts.nix`.
   - Keep `../../modules/packages/network.nix` and add a minimal explicit list of emergency router diagnostics (`pkgs.curl`, `pkgs.bind.dnsutils`, `pkgs.jq`) in `environment.systemPackages`.
   - Configure native Nix GC aligned with `modules/maintenance.nix`:
     - `nix.gc = { automatic = true; dates = config.yi.maintenance.slots.nixGc.calendar; options = "--delete-older-than 7d"; };` (and `systemd.timers.nix-gc.timerConfig = config.yi.maintenance.slots.nixGc.timerConfig;`).
   - Set minimal appliance overrides:
     - `users.defaultUserShell = pkgs.bashInteractive;` and `programs.zsh.enable = false;`
     - `programs.nix-ld.enable = false;`
     - `programs.command-not-found.enable = false;`
     - `nano` kept enabled (nixpkgs default; emergency console editor for broken-network fixes)
     - `documentation = { enable = false; doc.enable = false; info.enable = false; man.enable = false; nixos.enable = false; };`
     - `system.disableInstallerTools = true;` and `system.tools.nixos-version.enable = true;`
     - `xdg = { mime.enable = false; icons.enable = false; autostart.enable = false; menus.enable = false; portal.enable = false; };`
     - `fonts.fontconfig.enable = false;`
1. **Verify `hosts/yirukou/services.nix` stays intact**:
   - Keep `ssh`, `tailscale`, `adguardhome`, `unbound`, `valkey`, `nginx-proxy`, `monitoring/exporters.nix`, `monitoring/promtail.nix`, `monitoring/security-monitor`, and `./goaccess.nix` untouched.

### Phase 4 — Firmware & Kernel Module Trim (`hosts/yirukou/hardware.nix`)

1. **`hosts/yirukou/hardware.nix`**:
   - Keep `(modulesPath + "/installer/scan/not-detected.nix")` (or replace with explicit kernel/storage config) and override firmware defaults:
     - `hardware.enableRedistributableFirmware = false;`
     - `hardware.wirelessRegulatoryDatabase = false;`
     - `hardware.cpu.intel.updateMicrocode = true;` (explicit `true`, no longer tied to `enableRedistributableFirmware`)
   - Optionally blacklist unused `snd_sof_pci_intel_tgl` and `cfg80211` (and evaluate `i915` / `xe` vs physical HDMI console; see Open Questions).

### Phase 5 — Verification, Docs Update, & Live Deployment

1. **Documentation & cross-plan sync**:
   - Update `docs/src/hosts/yirukou.md` to reflect the minimal bash/appliance setup and `nix develop` workflow for ad-hoc dev tools.
   - Update `docs/src/services/nix-build-cache.md` if wrapper availability notes mention system packages vs `nix develop`.
   - Update `docs/src/plans/impermanence-yirukou-plan.md` so the planned `users.yi` / `users.root` persistence lists reflect `.bash_history` instead of `.zsh_history` and note the smaller `/nix` and `/` footprint.
1. **Evaluation, contract, and closure-size gates**:
   - Run `nix fmt -- --fail-on-change` and `nix flake check --no-build` (confirming `fleet-baseline`, `sshd-hardening`, `sshd-gate-coverage`, `proxy-allowlist`, `edge-no-tcp`, `exporter-source-scope`, `hardening-baseline`, `deploy-registry`, `docs`, and `docs-registry-sync` all pass).
   - Evaluate every host (`yirukou`, `yifuwuqi`, `yitaishi`, `yixiaoqing`, `yichuang`, `yijia`) to confirm zero unintended diffs on non-`yirukou` hosts aside from removing `packages/wrappers.nix` from `modules/packages/default.nix`.
   - Build `.#nixosConfigurations.yirukou.config.system.build.toplevel` (without switching) and measure closure reduction via `host-size yirukou` / `host-diff yirukou` against the `4.2 GiB` baseline.
1. **Deploy & post-deploy verification (User maintenance window)**:
   - Run `ci/deploy.sh dry yirukou`, then `ci/deploy.sh switch yirukou` (or `deploy .#yirukou`), and confirm rollback safety via `deploy-rs` magic rollback.
   - Verify on `yirukou`:
     - All 32 core systemd units (`adguardhome`, `unbound`, `redis`, `kea-dhcp4-server`, `nginx`, `tailscaled`, `sshd`, `wan-monitor`, `goaccess`, `vector`, all 10 `prometheus-*-exporter` units, `chronyd`, `smartd`) and `security-audit-fast` / `security-audit-cve` timers remain active.
     - `ai-ssh yirukou hostname` and `ssh yi@yirukou` work, and `nix develop` works cleanly as `yi` on `yirukou`.
     - If Phase 4 firmware changes are deployed, verify `dmesg` (`journalctl -b -k`) shows `igc` NICs, `nvme`, `microcode` early update, and clean tty1 console.

______________________________________________________________________

## Rollout order

- [x] **1.1** Deduplicate `packages/wrappers.nix` out of `modules/packages/default.nix` and add `pkgs.git`, `pkgs.neovim`, and the HM-derived `zsh`/TUI/`git` shell environment (`devShells.default` and `devShells.sandbox`) to `nix/devshell.nix` (AI).
- [x] **2.1** Decouple `home-manager` module from `flake.nix`'s `mkNixosHost` and `modules/common.nix` into `extraModules` and `modules/home-manager.nix`; guard `modules/nix-ld.nix` and parameterize `users/users.nix` options (AI).
- [x] **3.1** Strip `hosts/yirukou/configuration.nix` (remove Home Manager, `modules/packages`, `distributed-builds`, `nix-ld`, `zsh`, docs, installer tools, `command-not-found`, `xdg`/`fontconfig`; wire native `nix.gc` and minimal network/diagnostic tools) and update `modules/addresses/hosts.nix` (`yirukou.nixBuild.useRemoteBuilders = false`) (AI).
- [x] **4.1** Override `hardware.enableRedistributableFirmware = false` while keeping `hardware.cpu.intel.updateMicrocode = true` in `hosts/yirukou/hardware.nix` (AI).
- [x] **5.1** Update `docs/src/hosts/yirukou.md`, `docs/src/services/nix-build-cache.md`, and `docs/src/plans/impermanence-yirukou-plan.md` (AI).
- [x] **5.2** Run `nix fmt -- --fail-on-change`, `nix flake check --no-build`, per-host eval diff checks (`host-diff`), and build/measure `yirukou` closure size (`host-size yirukou`) — closure reduced from `4.2 GiB` to `2.1 GiB` (`/nix/store/kc6bz6334mg4njfhiy85hscw0nqdcgsb-nixos-system-yirukou-26.11.20261121.2786a2a`). The staged `flake.lock` bump of `home-manager` dropped `programs.wayprompt` while stylix still wrote it; `modules/home-manager.nix` now disables stylix's obsolete target, so every HM host evaluates again (AI).
- [x] **5.3** Deployed: `ci/deploy.sh switch` succeeded on `yirukou`, `yitaishi`, `yifuwuqi`. Live verification on `yirukou`: no failed units, all 10 `prometheus-*-exporter` units plus `adguardhome`, `unbound`, `redis`, `kea-dhcp4-server`, `nginx`, `tailscaled`, `sshd`, `wan-monitor`, `goaccess`, `vector`, `chronyd`, `smartd` active; `security-audit-fast`/`security-audit-cve` timers firing; `nix-gc.timer` scheduled from `slots.nixGc`; `curl`, `jq`, `dig`, `nano` and Lix present; `git`/`zsh`/`ai-ssh` absent from the system profile as designed (User + AI).
- [ ] **5.4** Post-reboot console check (firmware trim only takes effect on the next boot; the running system still uses the old `linux-firmware`) and a manual `nix develop` as `yi` (both devshell closures resolve fully from `cache.aset.love`, verified: 587/587 and 462/462 paths substitutable with zero misses).
- [ ] **5.5** Retire `docs/src/plans/yirukou-minimal-plan.md` once 5.4 passes (AI).

______________________________________________________________________

## Open questions

1. **Emergency editor (`nano` vs none)**: Resolved — `programs.nano` stays at the nixpkgs default (`true`, **53.5 MiB** closure / **2.6 MiB** self) so a broken-network console session can still edit files without `nix develop`.
1. **`nix-builder` & `sshd-hardening` contract**: `nix/checks.nix` currently requires `Match User nix-builder` in `services.openssh.extraConfig` on every registry host (`gateHosts`), and `modules/services/ssh/default.nix` sets `AllowUsers = [ ... "nix-builder" ... ]`. Should `yirukou` keep the lightweight `nix-builder` locked system user for contract uniformity, or should `sshd-hardening` and `AllowUsers` be narrowed to hosts with `nixBuild.remoteBuilder` / `forgejo-runner`?
1. **Integrated GPU / SOF kernel modules (`i915`, `xe`, `snd_sof_pci_intel_tgl`)**: Resolved — `i915`/`xe` stay loadable for HDMI console fallback. `linux-firmware` is out of the closure (`/run/current-system/firmware` resolves to an empty directory, 432 bytes self), so after the next reboot `i915` logs a failed `adlp_dmc.bin` load and falls back to basic modesetting. `snd_sof_pci_intel_tgl` and `cfg80211` still load because the blacklist lives in `modules/server-settings.nix`, not `hosts/yirukou/hardware.nix`; both are inert on a headless box.
