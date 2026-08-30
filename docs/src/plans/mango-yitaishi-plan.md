# Mango on yitaishi Plan

## Objective

Replace GNOME with **Mango** (mangowm, dwl/wlroots) on `yitaishi`, keeping:

- **HDR** on the two HDR-capable panels (LG 4K OLED TV, ASUS VG279QM) via mango `monitorrule` (`hdr:1`, Vulkan renderer).
- **Scrolling-tile** layout per monitor via mango `scroller` `tagrule`.
- **DMS** (DankMaterialShell), which already has a native Mango IPC client.
- All 3 monitors at their current modes (75 / 240 / 120 Hz) and positions, plus VRR on the ultrawide.

Hyprland also has HDR + DMS; it does not have mango's native scroller. This repo's niri path has no HDR output config. Mango is the chosen combo, not the only compositor in existence.

## Current State

- `yitaishi` runs GNOME: [`hosts/yitaishi/configuration.nix`](../../../hosts/yitaishi/configuration.nix) `host.desktopEnvironment = "gnome"`. `desktop.greeter` is already `"ly"`.

- NixOS `desktop.monitors` **is** set (GNOME dash-to-panel vendor-product names). [`modules/home-manager.nix`](../../../modules/home-manager.nix) defaults `monitors ? [ ]`; yitaishi does **not** pass `monitors` into `mkHome`, so **home-manager** `desktop.monitors = []`. GNOME is unaffected: dash-to-panel reads `osConfig.desktop.monitors` ([`modules/desktop/gnome/home.nix`](../../../modules/desktop/gnome/home.nix)). Empty home list only breaks compositor HM (niri/mango).

- If yitaishi were switched to niri today, eval would fail: [`flake.nix`](../../../flake.nix) imports `inputs.niri.nixosModules.niri` only on `yixiaoqing`. Home outputs would also be empty, and GNOME `name`s are not DRM connectors. None of that is a current eval failure under GNOME.

- Monitor entries (modes/positions match; connector names **not in git** — confirm on the machine with `wlr-randr` / `~/.config/monitors.xml` before freezing):

  | NixOS `name` (keep for GNOME) | role                    | mode                | position       |
  | ----------------------------- | ----------------------- | ------------------- | -------------- |
  | `GSM-0x000083cb`              | LG ultrawide (VRR, SDR) | `2560x1080@74.991`  | `(0, 2160)`    |
  | `AUS-S2LMQS085997`            | ASUS VG279QM (HDR)      | `1920x1080@239.760` | `(2560, 2160)` |
  | `GSM-0x01010101`              | LG TV SSCR2 4K (HDR)    | `3840x2160@120.000` | `(640, 0)`     |

  Likely connectors (unverified): ultrawide `DP-3`, ASUS `DP-1`, TV `HDMI-A-1` (GNOME `monitors.xml` often writes `HDMI-1`).

- nixpkgs `mango` is **0.16.2** (not 0.16.1), built with **scenefx**, plus `programs.mango`. The mangowm flake (`github:mangowm/mango`) provides `nixosModules.mango` / `hmModules.mango` (`wayland.windowManager.mango`) and **disables** nixpkgs `programs/wayland/mango.nix`.

- yitaishi is dual-AMD (Mesa/amdgpu in [`hosts/yitaishi/graphics.nix`](../../../hosts/yitaishi/graphics.nix)). Exact `cardN` ↔ PCI mapping is **not in this repo**. Verify on the host; mango documents `WLR_DRM_DEVICES` if the wrong card is selected.

## Decisions

1. **Compositor**: Mango, for native HDR `monitorrule` + native `scroller` + DMS.
1. **Flake, `wl-only` for HDR**: pin `github:mangowm/mango/wl-only` with `inputs.nixpkgs.follows = "nixpkgs"`. Official docs: HDR needs `WLR_RENDERER=vulkan`; scenefx is not Vulkan-compatible; HDR lives on `wl-only`. Flake `main` still pulls scenefx. If main later ships HDR without scenefx, drop the branch pin.
1. **No scenefx window effects** (blur/shadow/corners) while on Vulkan HDR. niri config did not rely on blur.
1. **Greeter**: keep `ly`. Flake `programs.mango.addLoginEntry` (default true) puts the `mango` session in `services.displayManager.sessionPackages`.
1. **Shell**: existing DMS, systemd-started. Do **not** use DMS's stock `exec-once=dms run` (double-start with [`users/programs/dms.nix`](../../../users/programs/dms.nix) `systemd.enable`).
1. **Dual GPU**: wlroots auto-select first; if no picture, `env = [ "WLR_DRM_DEVICES,/dev/dri/cardN" ]` after checking the host.
1. **HDR**: `hdr:1` on ASUS + TV; ultrawide SDR + `vrr:1`; global `hdr_depth = 2` (HDR10). Also set `hdr_max_lum` / `hdr_max_avg_lum` from EDID (`di-edid-decode`). `hdr_force:1` on the TV only if DisplayID 2.0 hides the HDR block.
1. **Monitor identity**: keep GNOME `name`s for dash-to-panel rollback. Add optional `connector` (plus `vrr` / `hdr` / lum) on the monitor submodule. Do **not** rename `name` to `DP-*`.
1. **Keybinds**: do not port the full niri bind table. Source DMS [`mango-binds.conf`](https://github.com/AvengeMedia/DankMaterialShell/blob/master/core/internal/config/embedded/mango-binds.conf) (niri uses `Mod+T` for kitty; DMS mango embeds `SUPER,t` and `SUPER,Return`).

## Phases

### Phase 1 — Wire the mango flake in

- **[`flake.nix`](../../../flake.nix)**
  - Input:
    ```nix
    mango = {
      url = "github:mangowm/mango/wl-only";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ```
  - On the **yitaishi** `nixosSystem` module list only: `inputs.mango.nixosModules.mango` (same `inputs.` prefix as niri on yixiaoqing).

### Phase 2 — Option plumbing

- **[`modules/options/host.nix`](../../../modules/options/host.nix)**: add `"mango"` to `host.desktopEnvironment`; `desktopShell` default `lib.elem config.host.desktopEnvironment [ "niri" "mango" ]` then `"dms"` else `null`.
- **[`modules/desktop.nix`](../../../modules/desktop.nix)**: add `"mango"` to `desktop.environment` (required — default copies `host.desktopEnvironment` and would type-fail otherwise); shell default `"dms"` for mango; greeter default for mango can stay unused on yitaishi (`ly` is already set); add `./desktop/mango.nix` to imports; extend portal `genAttrs` with `"mango"` (AppChooser/Access overrides). Rely on the flake mango module for wlr ScreenCast/Screenshot — do **not** copy niri's gnome portal.
- **[`modules/desktop/stylix.nix`](../../../modules/desktop/stylix.nix)**: include mango in the `mkIf` (`niri || gnome || mango`) so Ozone/Qt/stylix desktop targets apply.

### Phase 3 — Mango desktop module (NixOS)

- **New `modules/desktop/mango.nix`** (`mkIf (config.desktop.environment == "mango")`):
  - `programs.mango.enable = true;` (flake package / `addLoginEntry`).
  - Optional `environment.systemPackages` (`wlr-randr`).
  - `home-manager.users.yi.imports = [`
    - `inputs.mango.hmModules.mango`
    - `inputs.dms.homeModules.dank-material-shell`
    - `../../users/programs/mango.nix`
    - `../../users/programs/dms.nix`
    - `../../users/programs/noctalia` (same as niri.nix; noctalia is gated `niri && noctalia`, no-op here)
      `];`

### Phase 4 — Mango home module

- **New `users/programs/mango.nix`**:
  - `wayland.windowManager.mango.enable = true;`
  - `systemd.enable = true` (module default; starts `mango-session.target`). Optionally `programs.dank-material-shell.systemd.target = "mango-session.target"`.
  - Structured `settings` (wiki [nix-options](https://github.com/mangowm/mango/wiki/nix-options); **not** `docs/nix-options.md`). Duplicate keys are **lists of strings**:
    - `env = [ "WLR_RENDERER,vulkan" ];` plus optional `WLR_DRM_DEVICES`.
    - `hdr_depth = 2;`
    - `monitorrule` from `config.desktop.monitors`: parse `mode` (reuse niri `parseMode`) → width/height/refresh; `x`/`y`/`scale`; `vrr`/`hdr`/lum from new fields; `name:^${connector}$`.
    - `tagrule` with `layout_name:scroller` per tag.
    - `source` → `./dms/binds.conf` (and other dms fragments as needed); `bottomPrefixes = [ "source" ];`
  - **No** `exec-once=dms run`. DMS HM has **no** mango submodule (only niri includes).

### Phase 5 — Monitor option extension

- **[`modules/options/desktop.nix`](../../../modules/options/desktop.nix)** monitor submodule:
  - `connector` (nullOr str, default null) — DRM name for mango/niri.
  - `vrr` (bool, default false), `hdr` (bool, default false).
  - optional `hdrMaxLum` / `hdrMaxAvgLum` / `hdrMinLum` / `hdrForce`.

### Phase 6 — DMS gate + yitaishi host config

- **[`users/programs/dms.nix`](../../../users/programs/dms.nix)**: gate `lib.elem config.host.desktopEnvironment [ "niri" "mango" ] && config.host.desktopShell == "dms"`.
- **[`hosts/yitaishi/configuration.nix`](../../../hosts/yitaishi/configuration.nix)** (mirror yixiaoqing):
  - `let monitors = [ ... ];` with existing GNOME `name`s, added `connector` / `vrr` / `hdr` (and lum once measured).
  - `home-manager = mkHome { inherit inputs monitors; ... }`
  - `desktop = { inherit greeter monitors; ... }`
  - `host.desktopEnvironment = "mango";`
  - `host.desktopShell = "dms";`
  - Keep `greeter = "ly"`, `vr`, `workd`.

### Phase 7 — Verify

1. `nix flake check`; build `yitaishi`.
1. Hand the rebuild to the user — never `nixos-rebuild switch` from the agent.
1. `mango` session: three outputs, modes/positions (`wlr-randr` / `mmsg`). Confirm connectors vs the table.
1. HDR on ASUS + TV at **startup** (`hdr:1` in `monitorrule`). `mmsg dispatch togglehdr` is a **runtime** toggle and must not be the only enable path. VRR on ultrawide.
1. Scroller + per-monitor tags; DMS autostart (single instance); launcher/overview.
1. If black screen: set `WLR_DRM_DEVICES` from live `/dev/dri`.
1. Bind tune only if DMS `source` is insufficient.

## Rollout Order

1. Phase 1 + 2 (flake input + enums + stylix/portal) → eval.
1. Phase 3 + 4 + 5 (modules) → eval.
1. Phase 6 (host + DMS gate) → full eval + build.
1. Phase 7 (deploy + verify).

Config-only. Rollback: `host.desktopEnvironment = "gnome"` with **unchanged** GNOME monitor `name`s.

## Open Questions

- Confirm `wl-only` flake still evaluates against this nixpkgs (scenefx input / package attrs). If `main` has merged HDR+Vulkan without scenefx, unpin the branch.
- Live connector names and EDID lum values (`di-edid-decode`); TV `hdr_force`.
- Which `/dev/dri/cardN` owns the three panels.
- Whether `ly` lists the mango session; greetd/tuigreet only if it does not.
- Which DMS fragments besides `binds.conf` to `source` (colors/layout/cursor/outputs/windowrules) vs keep fully Nix-owned.
