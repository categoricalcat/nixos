# Audio Module Fixes (yitaishi)

## Status: IMPLEMENTED — 2026-10-30 (yitaishi rebuild pending)

Planned against `develop` at `daed5ba` plus the staged `pkgs.carla` re-enable and the two staged feature plans.

______________________________________________________________________

## Objective

1. Make `modules/audio/default.nix` do exactly what it claims: no dead, duplicate or overridden settings. Runtime behaviour stays the same except for three deliberate changes: the High Tide bitperfect rule starts applying, `VST3_PATH` reverts to musnix's default, and `WINEDLLOVERRIDES` is no longer set.
1. Restructure `modules/audio/` so the pending feature plans become additive: a new file in `packages/` plus list entries.
1. Bring `audio-midi-presets-plan.md` and `guitar-rig-plugins-plan.md` in line with the new structure and the verified facts. This touches plan docs only; neither feature is implemented here.

______________________________________________________________________

## Current State

Verified on yitaishi (`ai-ssh`) and against the PipeWire 1.6.9 / WirePlumber 0.5.18 sources and docs.

1. **Bluetooth block** `10-bluez-quality` has no effect. `bluez5.roles`, `bluez5.codecs` and `bluez5.enable-sbc-xq` are monitor properties: `bluez5-dbus.c` parses them only when the monitor starts, never from `monitor.bluez.rules`. `bluez5.a2dp.ldac.quality = "auto"` is already the default.
1. **PAM limits**: the generated `limits.conf` lists this module's `@audio - rtprio 95` first and musnix's `@audio - rtprio 99` later. The later line wins, so yi's user manager runs with rtprio 99, nice -11 (`Max nice priority 31`) and memlock unlimited. `memlock unlimited` is listed twice.
1. **High Tide rule** sits in `client.conf.d`.
   - High Tide's default `autoaudiosink` never picks `pipewiresink` (`GST_RANK_NONE`), so it ends up on `pulsesink`. Those streams go through pipewire-pulse, which reads `pipewire-pulse.conf.d`.
   - On the native PipeWire sink, `application.name` and `application.process.binary` both come from `/proc/self/exe`, which is `python3.13`, so the rule can't match there either.
1. **Session variables**:
   - `VST3_PATH` replaces musnix's `mkDefault` value and drops `/etc/profiles/per-user/$USER/lib/vst3`, where home-manager packages land (`useUserPackages = true`). The Wine VST3 path it adds has no consumer, since the plans say "No `yabridge`".
   - `WINEDLLOVERRIDES` only reaches Lutris and Proton.
1. **Duplicates of `modules/desktop.nix`**: `security.rtkit`, `services.pulseaudio.enable = false`, and PipeWire `enable`, `alsa`, `support32Bit` and `pulse`.
1. **Scarlett rules**:
   - WirePlumber 0.5.18 computes the default priority (1000 base, +1000 for capture, +500 for pro-audio, +100 for USB) before it applies `monitor.alsa.rules`. That makes the `priority.session` rules (1600 and 2600) restatements of the computed values.
   - `device.profile = "pro-audio"` is only read by `find-best-profile`, which is skipped once `find-preferred-profile` has selected pro-audio through `device.profile.priority.rules`.
1. **Structure**:
   - Repeated literals: the rate list (twice), the bitperfect props (twice), the `{ matches; actions.update-props }` shape, and 8 tmpfiles strings.
   - The file is 332 lines.
   - `mt-power-drum-kit.nix` uses the whole nix-ld list as `buildInputs`. Two builds with an identical RUNPATH exist in the store (`251a8…`, `4v4dz…`), rebuilt only because the nix-ld list changed.
   - `drum-locker.nix` is a documented opt-in template (`docs/src/audio/drums.md`).
1. **Feature plans (staged)**:
   - `audio-midi-presets-plan.md` adds compose tools, `modules/audio/home.nix` and `Music/midi-library/_user`.
   - `guitar-rig-plugins-plan.md` adds Hex Forge, Amp Locker and Rustortion derivations, plus `Audio/tapf` and `Audio/kpp`.
   - Both append to the `systemPackages` and tmpfiles lists that this plan moves.
1. **Verification constraint**: a git flake hides untracked files, and a `path:` flake would copy ignored files (`.opencode/`, `.venv/`, `.sops.yaml`) into the world-readable store.

______________________________________________________________________

## Decisions

1. **rtprio**: keep musnix's 99. Drop the local `rtprio` and `memlock` entries and keep only `nice -11`, PipeWire module-rt's default `nice.level`. There is no runtime change.
1. **Quantum**: keep min = max = 384 at 96 kHz.
1. **Bluetooth**: delete the block. Moving it to `monitor.bluez.properties` would re-enable HSP, which upstream disables because some headsets break with both `hsp_ag` and `hfp_ag`. Its codec list also omits `lc3`, which the `bap_*` roles need.
1. **Scarlett**: keep `device.profile.priority.rules` and drop the whole `monitor.alsa.rules` list.
1. **High Tide**: move the rule to `extraConfig.pipewire-pulse` with a single matcher, `application.name = "~[Hh]igh[- ]?[Tt]ide.*"`.
1. **Session variables**: delete both, so musnix's `mkDefault` plugin paths apply.
1. **Layout for growth**:
   - `default.nix` keeps realtime, PipeWire, WirePlumber and PAM.
   - `plugins.nix` owns the growth points: the flat `systemPackages` list and one list of writable directory names.
   - `packages/*.nix` is auto-wired with `lib.packagesFromDirectoryRecursive` into `audioPkgs`. Enabling a package means listing `audioPkgs.<name>`, and the lazy attrset never forces the `src = throw` template.
   - The root `packages/` plus `nix/overlays.nix` route was rejected, since that overlay is global and these packages are yitaishi-only.
1. **Drum kits**: keep each file's `{ pkgs, ... }` shape and replace only `nix-ld-libraries` with an explicit `with pkgs;` list taken from the live RUNPATH. That way git still records both moves as renames. The Drum Locker template starts from the same list.
1. **Not now**:
   - A shared vendored-binary builder: install layouts differ and only about 3 lines would be shared.
   - A WirePlumber device table: no new devices are planned.
   - Enable options: only one host imports the module.
1. **Feature plans**: review and update the docs only.

```text
modules/audio/
├── default.nix ───── musnix, rtirq, PipeWire, WirePlumber, PAM; imports ./plugins.nix
├── plugins.nix ───── systemPackages, writable $HOME dirs, audioPkgs wiring
└── packages/ ─────── callPackage files, auto-wired by lib.packagesFromDirectoryRecursive
    ├── mt-power-drum-kit.nix
    └── drum-locker.nix (template, src = throw)
```

______________________________________________________________________

## Phases

### Phase 1 — `default.nix`

- Remove the desktop duplicates, the Bluetooth block, the Scarlett `monitor.alsa.rules` and `environment.sessionVariables`. Fix the Scarlett comment to 2600 > 1600.
- Reduce PAM to the `nice -11` entry.
- Add the `rates`, `bitperfect` and `rule` helpers, and move the High Tide rule into `pipewire-pulse`.
- Set the module arguments to `_:` (repo convention) and add `imports = [ ./plugins.nix ];`.

### Phase 2 — `plugins.nix`

- Move `environment.systemPackages` in verbatim, including the staged `pkgs.carla`.
- Wire `audioPkgs = lib.packagesFromDirectoryRecursive { inherit (pkgs) callPackage; directory = ./packages; };`.
- Build the tmpfiles rules with `map` over the directory names.

### Phase 3 — `packages/`

- Move both drum-kit files with plain `mv` (no `git mv`). Change only the argument line and `buildInputs`, so the moves stay above git's 50% rename-detection threshold.
- `mt-power-drum-kit.nix`: `buildInputs = with pkgs; [ stdenv.cc.cc libx11 libxcb libxcb-util libxcb-cursor libxkbcommon glib cairo pango fontconfig ];`.

### Phase 4 — Docs

- `docs/src/audio/drums.md`: the new template path, and enabling it is one line.
- `docs/src/hosts/yitaishi.md`: list the module files, and credit rtkit to `modules/desktop.nix`.

### Phase 5 — Feature plans (docs only)

- `audio-midi-presets-plan.md`:
  - Point its edits at `plugins.nix` and the directory-name list.
  - Note the stale `VST3_PATH` statement.
  - Add the untracked-file verification caveat and the `workd` scoping question.
- `guitar-rig-plugins-plan.md`:
  - Use the standard format and fix the stale facts.
  - Put the derivations in `packages/`.
  - Use explicit arguments instead of the nix-ld list, non-deprecated X11 names and `pipewire.jack`.
  - Resolve the Hex Forge X11 UI and Amp Locker EX inconsistencies.

### Phase 6 — Verification

```bash
snap=/tmp/ai/<session-id>.tar
git ls-files -z --cached --others --exclude-standard |
  tar --null --ignore-failed-read --transform 's,^,source/,' -T - -cf "$snap"
probe='c: {
  pw = { inherit (c.services.pipewire.extraConfig) pipewire client jack pipewire-pulse; };
  wp = c.services.pipewire.wireplumber.extraConfig;
  limits = c.security.pam.loginLimits;
  env = c.environment.sessionVariables;
  pkgs = builtins.sort builtins.lessThan (map (p: p.name or "?") c.environment.systemPackages);
  tmpfiles = builtins.sort builtins.lessThan c.systemd.user.tmpfiles.rules;
}'
diff <(nix eval --json "git+file://$PWD?rev=$(git rev-parse HEAD)#nixosConfigurations.yitaishi.config" --apply "$probe" | jq -S .) \
     <(nix eval --option tarball-ttl 0 --json "tarball+file://$snap#nixosConfigurations.yitaishi.config" --apply "$probe" | jq -S .)
nix eval --option tarball-ttl 0 --raw "tarball+file://$snap#nixosConfigurations.yitaishi.config.system.build.toplevel.drvPath"
nix flake check --no-build --option tarball-ttl 0 "tarball+file://$snap"
```

- Gotchas behind those commands:
  - Nix accepts a flake tarball only with a single top-level directory, hence `--transform`. `tarball-ttl 0` stops it reusing a cached older snapshot.
  - `extraConfig` is probed per key, because evaluating the whole set hits the removed `client-rt` option, which throws.
  - A snapshot's system drvPath differs from a git checkout's even with identical content: `nix.registry.self` records the source's `lastModified`. Compare with that entry pinned.
- Build `mt-power-drum-kit` and compare its `readelf -d` NEEDED and RUNPATH with the live `4v4dz…` build.
- Run `nix fmt -- <changed files>`, then `DIRENV_IN_ENVRC=1 nix develop -c statix check modules/audio` and `DIRENV_IN_ENVRC=1 nix develop -c deadnix --fail modules/audio`. Without `DIRENV_IN_ENVRC=1`, the devshell's `exec zsh` hook swallows `-c` and the checks silently "pass".
- Confirm the index is unchanged, then audit `git diff`; `git diff HEAD -M --name-status` must show both drum kits as `R`.

### Phase 7 — Hand-off (user, on yitaishi)

```bash
su -                                            # then, as root:
nh os switch /home/yi/the.files/nixos           # then log out/in as yi
wpctl status                                    # Scarlett on pro-audio and default sink
wpctl inspect <scarlett-output-id> | rg priority            # 1600
wpctl inspect <high-tide-stream-id> | rg -i 'application.name|resample.disable'
printenv VST3_PATH WINEDLLOVERRIDES             # musnix path, no override
```

### Phase 8 — Upstream musnix (user submits)

There is no existing issue or PR. Keep the local line until a flake update brings this in:

```diff
       wantedBy = [ "multi-user.target" ];
+      # rtirq parses `chrt -p` with awk '/priority/'; localized output breaks it.
+      environment.LC_ALL = "C";
       path = with pkgs; [
```

______________________________________________________________________

## Rollout Order

1. The staged carla line and plan drafts can be committed at any time; nothing here depends on them.
1. Phases 1–6 happen in the working tree with no commits. Review `git diff` and commit (suggested split: config fixes / structure / docs and plans).
1. Rebuild yitaishi (Phase 7), then submit the musnix patch (Phase 8).
1. The MIDI and guitar features land later, each from its updated plan.

______________________________________________________________________

## Open Questions

1. High Tide's exact `application.name` under `pulsesink` (expected `high-tide`). Confirm with `wpctl inspect` and adjust the regex if it differs.
1. Drum Locker's real dependencies stay unknown until an archive is supplied; autoPatchelf will name what is missing.
1. Once the musnix fix lands, drop `systemd.services.rtirq.environment.LC_ALL`.
