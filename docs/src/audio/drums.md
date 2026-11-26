# Drum Kits & Plugins

## MT-PowerDrumKit

MT-PowerDrumKit 2 (v2.1.5.3, VST3) is automatically downloaded and patched for NixOS (`modules/audio/packages/mt-power-drum-kit.nix`). It provides a standard rock/pop drum kit with automatic piano-roll drum naming in REAPER out of the box.

## Audio Assault Drum Locker

Drum Locker v1.0.3 is automatically downloaded and patched by Nix (`modules/audio/packages/drum-locker.nix`). Upstream is plugin-only (no standalone binary), shipping native Linux VST3 and LV2 plugins linked into `/run/current-system/sw/lib/{vst3,lv2}` for REAPER.

Factory data (MIDI grooves and General MIDI mappings) is linked recursively into `~/Audio Assault/PluginData/Audio Assault/DrumLockerData/`, keeping the folders writable. Drum Locker includes a free 70s dry kit out of the box; optional purchased `.drm` drum libraries are installed from inside the plugin via its Install button.

## Versilian Virtuosity Drums (SFZ)

Virtuosity Drums v0.925 (CC0 contemporary jazz drum kit by Versilian Studios & Karoryfer Samples, 6 mixable mic positions) is fetched declaratively (`modules/audio/home.nix`) and linked read-only at `~/Audio/sfz/virtuosity-drums/`.

Load it with `sfizz` (VST3/LV2 plugin via `pkgs.sfizz-ui` in REAPER, or standalone via `pw-jack sfizz_jack`):

- `~/Audio/sfz/virtuosity-drums/Programs/01-basic-kit.sfz`: GM-compatible kit with basic articulations.
- `~/Audio/sfz/virtuosity-drums/Programs/02-full-kit.sfz`: full kit with extended articulations and mic-blend CC controls.
- `~/Audio/sfz/virtuosity-drums/Programs/03-kick-mic.sfz` through `08-vintage-mic.sfz`: individual mic-stem patches.

The folder also includes `VirtuosityDrumsManual.pdf` and `VirtuosityDrums_Keymap.pdf`.

## DrumGizmo Kits

DrumGizmo is an LV2 plugin (`drumgizmo.lv2` on the system profile) and ships no samples. REAPER's default LV2 search includes `/usr/lib/lv2`, which `modules/audio/default.nix` links at the system profile. Leave the LV2 path empty; a `~` in that field is not expanded. To get sound, download a drum kit.

**How to download and load a kit:**

1. Go to the [DrumGizmo Kits page](https://drumgizmo.org/wiki/doku.php?id=kits).
1. Download a kit (e.g., CrocellKit or MuldjordKit). These are large files (multi-gigabyte).
1. Extract the downloaded archive to a permanent folder on your disk, for example `~/Music/DrumGizmo/CrocellKit/`.
1. Open the DrumGizmo plugin in your DAW (like Reaper).
1. In the plugin interface, click "Browse" and select the `.xml` drumkit file located inside the folder you just extracted.
1. Ensure you route the multi-out channels correctly in your DAW, or load DrumGizmo as a stereo plugin if you don't need independent outputs.
