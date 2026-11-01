# AmpliTube 5 on NixOS

AmpliTube 5 is a Windows application. On `yitaishi`, Nix provides a dedicated Wine prefix, yabridge for REAPER, and WineASIO over PipeWire JACK. IK Product Manager, AmpliTube, and the license remain persistent user state because they require an IK account.

## Declarative Components

- Prefix: `~/.local/share/wineprefixes/ik-multimedia`
- Wine: nixpkgs' yabridge-matched Wine Staging
- Windows VST3 bridge: yabridge and yabridgectl
- Standalone audio: WineASIO, built for the same Wine; it loads PipeWire's `libjack.so.0` from the session `LD_LIBRARY_PATH` that `services.pipewire.jack.enable` sets
- Native bridged plugins: `~/.vst3/yabridge`
- Helper and launchers: `amplitube-5`, AmpliTube 5, and IK Product Manager

The helper disables Wine's menu builder, so the IK installers create no extra launchers or file associations; start everything from the two launchers above or through `amplitube-5`. No installer, credentials, serial number, or authorization data belongs in Git or the Nix store.

## First Installation

1. Rebuild `yitaishi` from a checkout that contains this configuration: run `su -`, then `nh os switch /mnt/smb/the.files/nixos`. A plain `nh os switch` builds `programs.nh.flake` (`/home/yi/the.files/nixos`), so update that clone first if you use it.

1. Download IK Product Manager for Windows from [IK Multimedia](https://ikmultimedia.com/en-us/pages/ik-product-manager) and extract its ZIP archive.

1. Create the prefix and run the extracted installer, adjusting the path for the downloaded version:

   ```bash
   amplitube-5 install "$HOME/Downloads/ik_product_manager_1.1.16/Install IK Product Manager (v.1.1.16).exe"
   ```

1. Launch `amplitube-5 manager`, sign in, and register the serial if it is not already attached to the account.

1. In Product Manager's Software tab, install and authorize AmpliTube 5. Keep the default standalone and VST3 destinations.

1. Bridge the installed VST3:

   ```bash
   amplitube-5 sync
   yabridgectl status
   ```

1. In REAPER, clear the VST cache and rescan. REAPER should discover `~/.vst3/yabridge/AmpliTube 5.vst3`; if `~/.vst3` is missing from Preferences → Plug-ins → VST, add it. Do not add the raw Wine prefix to REAPER's plugin paths.

## Standalone Mode

Launch from the desktop entry or run:

```bash
amplitube-5 standalone
```

AmpliTube opens inside a 1920x1080 Wine virtual desktop window, which niri floats because its size is fixed. On their own, Wine's dropdowns become separate windows under xwayland-satellite and close as soon as niri moves focus; inside the virtual desktop they behave normally. Maximize AmpliTube inside that window if needed; the size is set in `modules/audio/amplitube.nix`.

In AmpliTube's audio settings, select WineASIO. It follows the PipeWire graph at 96,000 Hz and 384 samples. Keep WineASIO's fixed buffer size on (the default): without it, WineASIO accepts only power-of-two buffer sizes, and 384 is not one. The helper re-registers WineASIO automatically after its Nix store path changes.

## Maintenance and Recovery

- Run `amplitube-5 manager` for IK updates, then `amplitube-5 sync`.
- Run `amplitube-5 winecfg` for prefix-specific Wine settings and `amplitube-5 winetricks VERB...` to add Windows components to the same prefix.
- The launchers report problems, such as Product Manager or AmpliTube not being installed yet, as desktop notifications.
- Wine Mono and Gecko are skipped when the prefix is created. None of the IK software needs them, and Wine still offers to install them the first time a program does.
- Preserve the whole prefix; it contains installed files, registry state, and authorization. Recreating it requires installing and authorizing again.
- After a yabridge or Wine update, rerun `amplitube-5 sync` before opening REAPER.
- If Product Manager reports download-path error 108, download AmpliTube from the IK account's My Products or Past Releases page, extract it, and run its installer with `amplitube-5 install <installer.exe>`. Use Product Manager afterward for authorization.
