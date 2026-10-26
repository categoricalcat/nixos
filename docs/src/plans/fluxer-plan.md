# Fluxer Package & Flatpak Removal Plan

## Objective

Create a native Nix package for Fluxer Desktop that runs the upstream AppImage via `appimage-run`, enabling seamless self-updating without needing hardcoded hashes on every release. Remove Flatpak from system desktop services and adapt the Fluxer GPU/VAAPI configuration flags in Home Manager to work with the native package.

## Current state

1. **Flatpak enablement**:
   - `modules/desktop.nix`: `services.flatpak.enable = true;`.
   - `modules/desktop/apps.nix`: `warehouse` installed (Flatpak manager).
1. **Fluxer config**:
   - `users/programs/fluxer.nix`: Activates `fluxer-flags.conf` into Flatpak sandbox path `$HOME/.var/app/app.fluxer.Fluxer/config/fluxer-flags.conf` with VAAPI / GPU acceleration flags:
     - `--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,VaapiIgnoreDriverChecks,AcceleratedVideoEncoder`
     - `--use-gl=angle`
     - `--use-angle=gl`
     - `--disable-gpu-sandbox`
1. **Upstream distribution**:
   - Available at `https://fluxer.app/download#desktop` (AppImage at `https://pkgs.fluxer.com/desktop/stable/linux/{arch}/latest/appimage`).
   - Fluxer contains built-in self-updating logic for AppImages (`applyStagedAppImageUpdate` in `AppImageUpdate`) that replaces the file referenced by `$APPIMAGE` in-place.

## Decisions

1. **AppImage runner wrapper package**:
   - Create `packages/fluxer/default.nix` providing a launcher script, desktop entry (`app.fluxer.FluxerDesktop.desktop`), and application icon.
   - On launch, the wrapper downloads the latest AppImage to `~/.local/share/fluxer/Fluxer.AppImage` if not present.
   - When executed via `appimage-run`, `APPIMAGE` environment variable is set to the mutable file in `~/.local/share/fluxer/Fluxer.AppImage`, allowing Fluxer's built-in updater to update in-place without touching the Nix store or requiring Nix flake bumps.
   - Wrapper reads flags from `$XDG_CONFIG_HOME/fluxer-flags.conf` (with fallback to `$HOME/.var/app/...`).
1. **Remove Flatpak**:
   - Remove `services.flatpak.enable = true;` from `modules/desktop.nix`.
   - Remove `warehouse` from `modules/desktop/apps.nix`.
   - Add `fluxer` to `modules/desktop/apps.nix`.
1. **Fluxer config updates**:
   - Update `users/programs/fluxer.nix` to declaratively install `fluxer-flags.conf` into `xdg.configFile."fluxer-flags.conf".text`.
1. **Overlay and Flake integration**:
   - Add `fluxer = prev.callPackage ../packages/fluxer { };` in `nix/overlays.nix`.
   - Expose `packages.fluxer` in `flake.nix` `perSystem`.

## Phases

- [x] Phase 1: Create `packages/fluxer/` with `default.nix`, `fluxer-launcher.sh`, and `fluxer.png`.
- [x] Phase 2: Expose `pkgs.fluxer` via `nix/overlays.nix` and `flake.nix`.
- [x] Phase 3: Update `users/programs/fluxer.nix` to use `xdg.configFile."fluxer-flags.conf"`.
- [x] Phase 4: Remove `services.flatpak.enable` from `modules/desktop.nix`, remove `warehouse` from `modules/desktop/apps.nix`, and add `fluxer`.
- [x] Phase 5: Non-destructive verification (linting, flake evaluation for hosts and homeConfigurations).

## Rollout order

1. `packages/fluxer/`
1. `nix/overlays.nix` & `flake.nix`
1. `users/programs/fluxer.nix`
1. `modules/desktop.nix` & `modules/desktop/apps.nix`
1. Verification via `nix flake check --no-build` and evaluation checks.

## Open questions

None. The user explicitly chose the self-updating AppImage wrapper approach to avoid manual hash management.
