# Server Headless Hygiene Plan

## Objective

Isolate desktop-only tools, graphical IDE launchers, and desktop system defaults away from headless server hosts (`yifuwuqi` and `yirukou`), while preserving Stylix and theme integration as explicitly requested.

______________________________________________________________________

## Current State

Both `yifuwuqi` (services server) and `yirukou` (gateway router) are headless machines without physical displays or graphical compositors. However, several desktop-only components leaked into their system closures:

1. **`shot` screenshot utility** (previously in `packages/wrappers.nix`):
   - Defined in universal base wrappers, pulling in `grim`, `slurp`, and `ksnip` (along with Qt/KDE dependencies `kcolorpicker` and `kimageannotator`) onto `yifuwuqi` and `yirukou`.
   - Work in working tree moved `shot` to `packages/shot.nix` and `modules/desktop/apps.nix`.
1. **Graphical IDE wrappers** (`nxd-cursor`, `nxd-antigravity` in `packages/wrappers.nix`):
   - Shell wrappers invoking graphical GUI IDEs (`code-cursor-nix#cursor` and `antigravity-nix#google-antigravity-ide`) are installed in `environment.systemPackages` on all machines.
   - Triggers `vscode-theme.nix` activation scripts in Home Manager to search for and invoke them with `--install-extension`.
1. **Desktop sound themes** (`xdg.sounds.enable`):
   - NixOS defaults `xdg.sounds.enable = true`, pulling `sound-theme-freedesktop` into system packages on both `yifuwuqi` and `yirukou`.
1. **Desktop user groups** (`adbusers` in `users/users.nix`):
   - Android Debug Bridge USB access group assigned to user `yi` on headless servers.

*Note on Stylix*: Stylix, fonts, wallpaper, and cursor/icon configurations on `yifuwuqi` are retained per user instruction.

______________________________________________________________________

## Decisions

1. **Keep Stylix & Font Configuration**: Retain `modules/stylix.nix` and `modules/fonts.nix` on `yifuwuqi`.
1. **Move GUI Wrappers to Desktop Packages**:
   - Relocate `nxd-cursor` and `nxd-antigravity` out of `packages/wrappers.nix` into `modules/desktop/apps.nix` (or a dedicated `packages/desktop-wrappers.nix`).
   - Keep CLI developer tooling (`diff-to-commit`, `nxd-agy`, `nxd-agent`, `nxd-opencode`, `seenix`) in base `packages/wrappers.nix`.
1. **Disable Desktop Sounds in `server-settings.nix`**:
   - Set `xdg.sounds.enable = false;` in `modules/server-settings.nix` to prevent `sound-theme-freedesktop` from polluting headless server closures.
1. **Gate Android Debugger User Group**:
   - Make `adbusers` conditional on desktop environments (`config.host.desktopEnvironment != null`) or desktop hosts.

______________________________________________________________________

## Phases

### Phase 1: Working Tree Consolidation

- Confirm the `shot` extraction (`packages/shot.nix` and `modules/desktop/apps.nix`) is finalized.

### Phase 2: Relocate GUI Desktop Wrappers

- Move `nxd-cursor` and `nxd-antigravity` from `packages/wrappers.nix` to `modules/desktop/apps.nix`.
- Verify devshell and desktop hosts retain access to the wrappers.

### Phase 3: Headless Server Settings Hardening

- In `modules/server-settings.nix`, add `xdg.sounds.enable = false;`.
- In `users/users.nix`, restrict `adbusers` group to desktop hosts.

### Phase 4: Verification & Closure Comparison

- Evaluate NixOS system toplevel derivations for `yifuwuqi`, `yirukou`, `yitaishi`, and `yixiaoqing`.
- Verify absence of `shot`, `grim`, `slurp`, `ksnip`, `nxd-cursor`, `nxd-antigravity`, and `sound-theme-freedesktop` on `yirukou`.
- Verify presence of all expected desktop tools on `yitaishi` and `yixiaoqing`.

______________________________________________________________________

## Rollout Order

1. `packages/wrappers.nix` & `modules/desktop/apps.nix`
1. `modules/server-settings.nix`
1. `users/users.nix`
1. Evaluation checks across all 4 machine configurations.

______________________________________________________________________

## Open Questions

- Should `nxd-cursor` and `nxd-antigravity` remain in repo `devShells` for developers working via SSH, or should they be strictly desktop-only? (Recommended: desktop-only, keeping `nxd-agent` and `nxd-agy` in devshell).
