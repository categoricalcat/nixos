# AmpliTube 5 on NixOS

AmpliTube 5 is a Windows application. On `yitaishi`, `modules/audio/amplitube.nix` provides a dedicated Wine prefix (`~/.local/share/wineprefixes/ik-multimedia`), yabridge for REAPER, WineASIO over PipeWire JACK, and two app launchers: **IK Product Manager** and **AmpliTube 5**. Signing in, installing, and authorizing stay in IK Product Manager because they need an IK account; nothing account-related goes into Git or the Nix store.

## Setup

1. Rebuild `yitaishi`: run `su -`, then `nh os switch /mnt/smb/the.files/nixos`. A plain `nh os switch` builds `programs.nh.flake` (`/home/yi/the.files/nixos`), so update that clone first if you use it.
1. Open **IK Product Manager** from the app launcher. The first launch creates the prefix and installs Product Manager silently. Sign in, then install and authorize AmpliTube 5 with the default paths.
1. Open **AmpliTube 5** from the app launcher and select WineASIO in its audio settings.

For REAPER, the `yabridge-sync` user service bridges the prefix's VST3 folder into `~/.vst3/yabridge` at login, after every rebuild, and whenever an installation changes the plugin. Clear REAPER's VST cache and rescan once; if `~/.vst3` is missing from Preferences → Plug-ins → VST, add it. Do not add the raw Wine prefix to REAPER's plugin paths.

## Behavior

- AmpliTube opens inside a 1920x1080 Wine virtual desktop window, which niri floats because its size is fixed. On their own, Wine's dropdowns become separate windows under xwayland-satellite and close as soon as niri moves focus; inside the virtual desktop they behave normally. Maximize AmpliTube inside that window if needed; the size is set in `modules/audio/amplitube.nix`.
- WineASIO follows the PipeWire graph at 96,000 Hz and 384 samples. Keep its fixed buffer size on (the default): without it, WineASIO accepts only power-of-two buffer sizes, and 384 is not one.
- Wine's menu builder is disabled, so the IK installers create no extra launchers or file associations. Wine Mono and Gecko are skipped when the prefix is created; none of the IK software needs them, and Wine still offers to install them the first time a program does.
- The launchers report problems, such as AmpliTube not being installed yet, as desktop notifications.

## Maintenance

- Update IK software from IK Product Manager; the sync service picks up new plugin files on its own.

- Plugin folders are declared in Nix and `~/.config/yabridgectl/config.toml` is read-only, so `yabridgectl add` does not apply. `yabridgectl status` still works, and `journalctl --user -u yabridge-sync` shows the sync log.

- Preserve the whole prefix; it contains installed files, registry state, and authorization. Recreating it means installing and authorizing again.

- If Product Manager reports download-path error 108, download AmpliTube from the IK account's My Products or Past Releases page, extract it, run its installer in the prefix, then authorize in Product Manager:

  ```bash
  WINEPREFIX=~/.local/share/wineprefixes/ik-multimedia WINEDLLOVERRIDES=winemenubuilder.exe=d \
    nix shell nixpkgs#wineWow64Packages.yabridge -c wine "<installer.exe>"
  ```
