# HDR Desktop: Review & Screenshot Fixes

## Objective

Make `desktop.hdr` work on mango and niri for both shells (DMS, Noctalia), with screenshots that come out right on HDR outputs. The `niri-spicy` fork integration and night light stay as staged.

______________________________________________________________________

## Current State

- `desktop.hdr` ([`modules/options/desktop.nix`](../../modules/options/desktop.nix)) is the global switch, forwarded to Home Manager by [`modules/home-manager.nix`](../../modules/home-manager.nix). Per-monitor fields: `hdr`, `hdrMinLum`, `hdrMaxLum`, `hdrMaxAvgLum`, `hdrForce` (mango) and `hdrMode`, `hdrReferenceLuminance` (niri-spicy only).
- **mango** ([`users/programs/mango.nix`](../../users/programs/mango.nix)): `monitor_rule` gets `hdr:1` and the mastering fields only when `desktop.hdr && m.hdr`. HDR needs the Vulkan renderer (`env=WLR_RENDERER,vulkan`, always set).
- **niri** ([`modules/desktop/niri.nix`](../../modules/desktop/niri.nix), [`users/programs/niri.nix`](../../users/programs/niri.nix)): with `desktop.hdr` the package is [`packages/niri-spicy.nix`](../../packages/niri-spicy.nix) (`losnoco/niri` `spicy-main` + `losnoco/smithay` `spicy-master`; the fork's `Cargo.toml` `[patch] path = "../smithay"` is substituted with the smithay input), and an `hdr mode=… { reference-luminance; peak-luminance }` node is injected into each HDR `output`. Upstream niri has no HDR, only per-output `max-bpc` (niri-wm/niri#3158).

______________________________________________________________________

## Decisions

1. Keep the `niri-spicy` fork as staged: opt-in through `desktop.hdr`, pinned by `flake.lock`. No HDR fork avoids losnoco code; dividebysandwich `hdr-smithay-master` merges losnoco's `color-management-features`.
   - `losnoco/niri` `spicy-main`: 67 ahead, 42 behind upstream, last commit 2026-10-09. `losnoco/smithay` `spicy-master`: 49 ahead, 35 behind.
   - `dividebysandwich/niri` `hdr-smithay-master`: 19 ahead, 159 behind, last commit 2026-07-10, no `peak-luminance`.
1. Keep DMS and Noctalia night light under HDR (see limitations).
1. Change screenshots only; the rest of the staged diff stays.
1. No `DESKTOP_HDR` variable. `shot` reads live mango state, so `mmsg dispatch togglehdr` is respected without a re-login.

______________________________________________________________________

## Screenshots

What a capture contains on an HDR output:

- **mango (wlroots 0.20.2)**: screencopy copies the output buffer raw (`WLR_RENDER_BLEND_MODE_NONE`, no color transform), so `grim` and shell captures are PQ / BT.2020.
- **niri-spicy**: captures are downmixed to SDR (`set_sdr_capture_blend`), but the output's color-management description stays PQ / BT.2020 with `mode="on"` (`description_for_output` returns `output_blend_description`).

Routing:

- **mango, any shell, `desktop.hdr`**: every screenshot bind calls `shot` ([`nix/scripts/shot.sh`](../../nix/scripts/shot.sh), binds in [`modules/desktop/keybinds.nix`](../../modules/desktop/keybinds.nix)). `shot` checks `is_hdr` from `mmsg get monitor <name>` and converts with `zscale=tin=smpte2084:pin=bt2020:t=iec61966-2-1:p=bt709:npl=203`. Without `desktop.hdr`, Noctalia keeps its own region and fullscreen capture.
- **niri-spicy + DMS**: DMS's `binds.kdl` include is loaded after ours, and `dms screenshot` writes the output's `cICP` (PQ) onto SDR pixels. With `hdr`, its screenshot binds are rewritten to niri's `screenshot`, `screenshot-screen` and `screenshot-window`.
- **niri-spicy + Noctalia**: niri's built-in actions are already bound; nothing to change.

Why `npl=203`: wlroots maps SDR white with `ref_dst / ref_src * max_src / max_dst`, using default luminances sRGB `{0.2, 80, 80}` and PQ `{0.005, 10000, 203}` (`render/color.c`, `types/scene/wlr_scene.c`). That puts SDR white at 203 cd/m²; the old `npl=190` clipped near-white values.

______________________________________________________________________

## Known Limitations

- **Night light on HDR outputs**: wlroots applies the shell's gamma ramp after PQ encoding (hardware `GAMMA_LUT`, or last in the render transform chain). Noctalia scales the encoded signal per channel, so at 3700 K blue lands near 9% of white instead of about 32%: a much stronger, darker tint. Neither shell can exclude individual outputs (DMS only excludes apps).
- **Shell panel screenshot buttons on mango HDR** stay raw PQ. DMS tags them with `cICP`, so color-managed viewers (browsers) show them correctly; Noctalia saves them untagged, so they look washed out. Use the keybinds.
- **Regions spanning HDR and SDR outputs** are converted as a whole, based on the output `slurp` reports.
- **Highlights**: `zscale` clips content brighter than 203 cd/m² (HDR games, video).

______________________________________________________________________

## Review Notes

- Correct staged changes: dropping trackball `scroll-factor` (niri-flake's trackball schema has no such option); dropping `niri-flake-polkit` is harmless because nixpkgs `programs.niri` is used, not niri-flake's NixOS module.
- Pre-existing, unchanged:
  - niri `typedOutputs` drops `vrr`.
  - `position = {}` when a monitor has no position; niri-flake expects `null`.
  - `hdr_depth = 2` repeats mango's 10-bit default.
  - The fork inputs track branches; only `flake.lock` pins them, so `nix flake update` pulls unreviewed commits.
  - mango applies the first matching `monitor_rule` at startup but the last one on reload, and `dms/outputs.conf` is sourced after the Nix rules. DMS carries unmodeled fields such as `hdr:` over from existing rules, so a stale `hdr:0` there can turn HDR off after a reload.

______________________________________________________________________

## Client Notes (checked Oct 2026)

- Chromium / Chrome: `WaylandWpColorManagerV1` has been on by default since Chrome 141; no flag needed.
- mpv 0.41 and later: `gpu-next` and `target-colorspace-hint=auto` are the defaults.
- Firefox: `gfx.wayland.hdr = true` (off by default).
- Proton: GE-Proton uses `PROTON_ENABLE_WAYLAND=1 PROTON_ENABLE_HDR=1`; Proton-EM dropped `PROTON_ENABLE_HDR` (`DXVK_HDR=1` still works).
- mango advertises color-management v1 with parametric descriptions and mastering primaries; transfer functions and primaries come from the Vulkan renderer.

______________________________________________________________________

## Verification

- Eval: `nix eval .#nixosConfigurations.yitaishi.config.system.build.toplevel.drvPath`
- Binds: `nix eval --raw '.#nixosConfigurations.yitaishi.config.home-manager.users.yi.xdg.configFile."mango/dms/binds.conf".text' | rg shot`
- On yitaishi: `shot area` on DP-1 (HDR) and DP-3 (SDR) should give matching whites; repeat with `desktopShell = "noctalia"`.
