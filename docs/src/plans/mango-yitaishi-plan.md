# Mango on yitaishi Plan

## Objective

Replace GNOME with **Mango** (mangowm, a dwl/wlroots Wayland compositor) on the `yitaishi` desktop host, while keeping:

- **HDR** on the two HDR-capable monitors (LG 4K OLED TV, ASUS VG279QM) — niri has no HDR, Mango supports per-monitor HDR10.
- **Scrolling-tile** layout on each monitor independently — Mango's native `scroller` layout per tag.
- The **DMS** (DankMaterialShell) desktop shell, which natively supports MangoWC.
- All 3 monitors at their exact modes (75 / 240 / 120 Hz) with correct positions, plus VRR on the ultrawide.

## Current State

- `yitaishi` runs GNOME (`hosts/yitaishi/configuration.nix`, `host.desktopEnvironment = "gnome"`).
- `niri` cannot run on `yitaishi` today:
  1. `flake.nix` does not import `inputs.niri.nixosModules.niri` for `yitaishi` (only `yixiaoqing`) → eval fails on `programs.niri.settings` / `niri-flake-polkit`.
  1. `mkHome` call in `hosts/yitaishi/configuration.nix` never passes `monitors` → home `desktop.monitors = []` (verified via eval).
  1. Monitor entries use GNOME `monitors.xml` names, which niri ignores.
- **niri also has no HDR support at all** (confirmed in niri source) → out of scope as the desktop.
- The 3 monitors (from `~/.config/monitors.xml` last config block):
  - `DP-1` = ASUS VG279QM, `1920x1080@239.760`, pos `(2560, 2160)`, primary, HDR (`bt2100`)
  - `DP-3` = LG HDR WFHD ultrawide, `2560x1080@74.991`, pos `(0, 2160)`, VRR (`ratemode variable`)
  - `HDMI-A-1` = LG TV SSCR2 4K, `3840x2160@120.000`, pos `(640, 0)`, HDR (`bt2100`) — kernel name is `HDMI-A-1`, GNOME writes `HDMI-1`
- Mango is already packaged: nixpkgs `mango` 0.16.1 + `programs.mango` module; mangowm flake provides `nixosModules.mango` + `hmModules.mango` (`wayland.windowManager.mango`).
- `yitaishi` has two AMD GPUs: card0 (`0000:13:00.0`, unused displays: DP-4, HDMI-A-2) and card1 (`0000:03:00.0`, the RX 7900 XTX with all 3 monitors). niri/smithay enumerates all cards; wlroots auto-selects the card with displays.

## Decisions

1. **Compositor**: Mango (mangowm), not Hyprland/scroll/Miracle — it is the only option with native HDR + native scroller layout + per-tag independent layout + DMS support.
1. **Flake package over nixpkgs**: use the mangowm flake (`github:mangowm/mango`) so we get the declarative home module (`wayland.windowManager.mango`), the `mango-session.target` (which DMS binds to), and the latest source build. nixpkgs' `programs.mango` NixOS module is disabled by the flake module (`disabledModules`).
1. **HDR priority over scenefx window effects**: HDR requires `WLR_RENDERER=vulkan`; mango's docs note HDR lives in the `wl-only` branch because scenefx (blur/shadow/corner radius) is not Vulkan-compatible. Accept dropping scenefx effects; the niri config did not use blur. Fallback: overlay the `wl-only` branch if the flake `main` package does not expose working HDR.
1. **Greeter**: keep `ly` (it lists the `mango` wayland session from the package). No greeter change unless it breaks.
1. **Shell**: `dms` (DankMaterialShell), the existing shell, which supports Mango natively.
1. **Dual GPU**: rely on wlroots primary-card auto-detection; fallback `env = ["WLR_DRM_DEVICES,/dev/dri/card1"]` if no displays.
1. **HDR targets**: `hdr:1` on `DP-1` and `HDMI-A-1` (matches GNOME `bt2100`); `DP-3` stays SDR with `vrr:1`. `hdr_depth = 2` (HDR10). If the LG TV's HDR block hides in a DisplayID 2.0 extension, add `hdr_force:1` on `HDMI-A-1`.

## Phases

### Phase 1 — Wire the mango flake in

- **`flake.nix`**
  - Add input:
    ```nix
    mango = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ```
  - In the `yitaishi` nixosSystem module list, add `mango.nixosModules.mango`.

### Phase 2 — Option plumbing

- **`modules/options/host.nix`**: add `"mango"` to the `host.desktopEnvironment` enum; change `desktopShell` default to `lib.elem config.host.desktopEnvironment [ "niri" "mango" ]`.
- **`modules/desktop.nix`**: add `"mango"` to the `desktop.environment` enum; update the `shell` default to return `"dms"` for mango; add `./desktop/mango.nix` to imports.

### Phase 3 — Mango desktop module (NixOS side)

- **New `modules/desktop/mango.nix`** (`mkIf (config.desktop.environment == "mango")`):
  - `programs.mango.enable = true;`
  - `environment.systemPackages` additions (e.g. `wlr-randr`).
  - `home-manager.users.yi.imports = [ mango.hmModules.mango inputs.dms.homeModules.dank-material-shell ../../users/programs/mango.nix ../../users/programs/dms.nix ../../users/programs/noctalia ];`

### Phase 4 — Mango home module (config generation)

- **New `users/programs/mango.nix`** (mirrors `users/programs/niri.nix`):
  - `wayland.windowManager.mango.enable = true;`
  - `settings`:
    - `env = [ "WLR_RENDERER,vulkan" ]` (plus optional `WLR_DRM_DEVICES` fallback).
    - `hdr_depth = 2;`
    - `monitorrule` entries generated from `config.desktop.monitors`: parse `mode` → `width`/`height`/`refresh`; reuse `x`/`y`/`scale`; emit `vrr`/`hdr` from the new option fields. Names use connector keys (`^DP-1$`, `^DP-3$`, `^HDMI-A-1$`).
    - `tagrule = [ "id:1,layout_name:scroller" ... ]` for scrolling-tile layout.
    - Core keybinds ported from the niri binds (`Mod+Return` terminal, `Mod+Space` DMS launcher, workspace/column scroll, etc.). DMS supplies its own bind layer for Mango at runtime.
  - `systemd` / session wiring so DMS autostarts against `mango-session.target`.

### Phase 5 — Monitor option extension

- **`modules/options/desktop.nix`**: add `vrr` (bool, default `false`) and `hdr` (bool, default `false`) to the monitor submodule (and optionally `hdrMaxLum`/`hdrMaxAvgLum` for mastering metadata).

### Phase 6 — DMS gate + yitaishi host config

- **`users/programs/dms.nix`**: widen gate from `desktopEnvironment == "niri"` to `lib.elem ... [ "niri" "mango" ]` (and require `desktopShell == "dms"`).
- **`hosts/yitaishi/configuration.nix`**:
  - Extract a `monitors` let-binding; pass `inherit monitors;` to `mkHome` (fixes the empty `desktop.monitors` bug).
  - Rename the 3 monitor entries to `DP-1` / `DP-3` / `HDMI-A-1`; add `vrr`/`hdr` flags per the table in Current State.
  - `host.desktopEnvironment = "mango";`
  - `host.desktopShell = "dms";`
  - Keep `greeter = "ly"`, `vr`, `workd` as-is.

### Phase 7 — Verify

1. `nix flake check`; build the `yitaishi` configuration.
1. Deploy (hand the rebuild command to the user — never run `nixos-rebuild switch`).
1. Boot into the `mango` session; confirm all 3 monitors appear at correct mode/position (via `wlr-randr` / mango IPC `mmsg`).
1. Confirm HDR activates on `DP-1` and `HDMI-A-1` (`mmsg dispatch togglehdr`), VRR on `DP-3`.
1. Confirm scroller layout and per-monitor tag independence; confirm DMS shell autostarts and the launcher/overview work.
1. Iterate on keybind tuning (DMS vs `config.conf` binds).

## Rollout Order

1. Phase 1 + 2 (flake input + enums) → eval sanity check.
1. Phase 3 + 4 + 5 (modules) → eval sanity check.
1. Phase 6 (host config + DMS gate) → full eval + build.
1. Phase 7 (deploy + verify + tune).

All changes are config-only; GNOME remains selectable by flipping `host.desktopEnvironment = "gnome"` if a rollback is needed.

## Open Questions

- Whether the mangowm flake `main` package exposes working HDR (Vulkan renderer) — verify first; fallback is overlaying the `wl-only` branch.
- Exact `wayland.windowManager.mango` key spellings for `env` / `monitorrule` / `hdr_depth` in the HM module (confirm against mango's generated options, `docs/nix-options.md`).
- Whether the LG TV needs `hdr_force:1` (DisplayID 2.0 HDR block hiding).
- DMS ↔ mango keybind split (how much to hardcode in `config.conf` vs let DMS own).
- Keep `ly` greeter or switch to greetd/tuigreet if ly + mango session misbehaves.
