# Drum Kits & Plugins

## MT-PowerDrumKit

This plugin is automatically downloaded and patched for NixOS. It provides a standard rock/pop drum kit right out of the box.

## Audio Assault Drum Locker

Because Drum Locker requires a purchase and an account login, Nix cannot fetch it automatically.

**Installation Steps:**

1. Log in to your Audio Assault account.
2. Download the Linux version (usually a `.zip` archive).
3. Open `/home/yi/the.files/nixos/modules/audio/drum-locker.nix` in your text editor.
4. Replace the `src = throw ...` line with the path to your downloaded file. For example: `src = /home/yi/Downloads/DrumLocker_Linux.zip;`
5. Uncomment `# drum-locker` in `/home/yi/the.files/nixos/modules/audio/default.nix` under the `environment.systemPackages` section.
6. Run `nixos-rebuild switch`.

## DrumGizmo Kits

DrumGizmo is just a sample engine. It **does not** include drum sounds out-of-the-box. To get sound, you need to download a drum kit.

**How to download and load a kit:**

1. Go to the [DrumGizmo Kits page](https://drumgizmo.org/wiki/doku.php?id=kits).
2. Download a kit (e.g., CrocellKit or MuldjordKit). These are large files (multi-gigabyte).
3. Extract the downloaded archive to a permanent folder on your disk, for example `~/Music/DrumGizmo/CrocellKit/`.
4. Open the DrumGizmo plugin in your DAW (like Reaper).
5. In the plugin interface, click "Browse" and select the `.xml` drumkit file located inside the folder you just extracted.
6. Ensure you route the multi-out channels correctly in your DAW, or load DrumGizmo as a stereo plugin if you don't need independent outputs.
