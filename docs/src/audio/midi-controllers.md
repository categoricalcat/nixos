# MIDI Controllers

## Novation Launchkey Mk4 25

Class-compliant USB MIDI controller: no driver, no udev rules — `snd-usb-audio` claims it, PipeWire/WirePlumber expose it as ALSA MIDI nodes automatically. Bus-powered; `usbcore.autosuspend=-1` (yitaishi) prevents USB dropouts.

**Kernel**: below 6.12 both MIDI ports enumerate with duplicated names, which breaks DAW port matching; fixed by ALSA commit `0759e77a6d9bd34a` (kernel ≥6.12). `yitaishi` runs `linuxPackages_latest`, so the port names are distinct.

### Ports

Two bidirectional USB MIDI interfaces:

```text
Port    Client name       Port name
xx:0    Launchkey MK4 25  Launchkey MK4 25 MIDI In   ← keys, pads, knobs, custom modes
xx:1    Launchkey MK4 25  Launchkey MK4 25 DAW In    ← DAW-mode control surface
```

Verify with `aplaymidi -l` / `aconnect -l`; `amidi -l` shows the raw pairs as `hw:X,0,0` (MIDI) and `hw:X,0,1` (DAW). Both also appear as MIDI nodes in `qpwgraph`. `alsa-utils` (aconnect/amidi/aplaymidi) ships via `modules/audio/plugins.nix`.

### Quick test rig (no DAW)

- Events: `aseqdump -p <port>` or **ShowMIDI** — GUI monitor with per-port streams, shows notes/CC/SysEx from keys, pads, knobs and the DAW surface.
- Sound: connect the `MIDI In` port to any standalone synth in `qpwgraph` — yoshimi, bespokesynth, surge-xt, vital; or GM playback with `fluidsynth -g 2 -m alsa_seq /run/current-system/sw/share/soundfonts/FluidR3_GM.sf2`.
- Pads → drums: hydrogen (MIDI learn per pad) or geonkick.
- Loops: sooperlooper — MIDI-learnable record/overdub/multiply controls.

### REAPER

Playing: Preferences → MIDI Devices → enable `Launchkey MK4 25 MIDI In` as input.

Control surface (Novation's official procedure):

1. Options → Preferences → Control/OSC/web → Add → **HUI (partial)**.
1. MIDI input: `Launchkey MK4 25 DAW In`; MIDI output: `Launchkey MK4 25 DAW In` — ALSA ports are bidirectional, one port fills both dropdowns. (Novation's doc names them `DAW Out`/`DAW In` after the Windows driver; same ports.)
1. On the keyboard, press **DAW** (InControl) to enable DAW mode.

HUI mapping on the 25: pads = Mute/Solo and Arm/Select (Function toggles), encoders = volume/pan in Mixer mode or Sends A–E in Sends mode (Encoder Bank switches), transport = Play/Record/Stop. Shift + encoder previews the parameter on the keyboard screen without changing it.

### ReaLearn (via ReaPack)

ReaLearn maps the Launchkey to anything in REAPER — tracks, FX parameters, custom targets — beyond what HUI covers. ReaPack itself ships via Nix: `modules/audio/home.nix` symlinks its `.so` into `~/.config/REAPER/UserPlugins`.

1. Extensions → ReaPack → **Import repositories**: `https://github.com/helgoboss/reaper-packages/raw/master/index.xml`
1. Extensions → ReaPack → Browse packages → search `helgobox` → install **Helgobox: ReaLearn & Playtime** → restart REAPER.
1. Insert the `Helgobox - ReaLearn & Playtime` FX on a track, add a controller, import a Launchkey preset (preset cloud) or map controls manually.
1. Keep ReaPack's own self-update disabled — the extension is Nix-managed and a ReaPack update would clobber the symlink.

If the FX doesn't appear, check REAPER's plugin scan log for missing `libx11`/`libstdc++`/`libudev` (all present on `yitaishi`).

### Firmware (Components)

Firmware updates and custom modes go through Novation Components, a Web MIDI (SysEx) app at [components.novationmusic.com](https://components.novationmusic.com). Linux is unsupported by Novation: **Google Chrome works; Chromium usually fails the SysEx handshake.**

1. Open Components in Chrome and allow MIDI access when prompted.
1. If an update is offered, confirm on the keyboard with the Scene Launch `>` button within 10 seconds.

Fallback without Components: hold **Octave Up + Octave Down** while powering on to enter bootloader mode (screen shows firmware versions), then flash a `.syx` directly:

```bash
amidi -l                         # bootloader port, e.g. hw:2,0,0
amidi -p hw:2,0,0 -s <firmware>.syx
```
