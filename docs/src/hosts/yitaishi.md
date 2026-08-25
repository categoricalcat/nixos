# Host Profile: yitaishi (Workstation & Studio)

`yitaishi` is the primary desktop workstation, remote Nix build node, real-time pro-audio studio (DAW), and gaming/racing simulation rig.

______________________________________________________________________

## 1. System & Hardware Specifications

| Component               | Specification                                                                       |
| ----------------------- | ----------------------------------------------------------------------------------- |
| **Role**                | Workstation, Remote Nix Builder, Audio Studio, Sim Racing, VR                       |
| **Architecture**        | `x86_64-linux` (AMD Ryzen CPU + AMD Radeon RX 7900 XTX)                             |
| **GPU / Acceleration**  | AMD Radeon RX 7900 XTX (24 GB VRAM, gfx1100, ROCm / HIP enabled)                    |
| **Kernel & Boot**       | `linuxPackages_zen` kernel, Lanzaboote UEFI Secure Boot (`sbctl`)                   |
| **Filesystems**         | Btrfs root (`2e6f5a45-d509-48fb-ac15-47788d92fd95`) with `@` and `@home` subvolumes |
| **Mounted Drives**      | `/mnt/slowass` (XFS), `/mnt/jooj` (XFS), `/mnt/windows` (NTFS3 automount)           |
| **Swap & Memory**       | Dedicated Swap partition (`a33ec516-9670-4fd7-90ce-e94d7b245051`) + ZRAM            |
| **Power Profile**       | Ultra-performance zero-power-saving policy (`tuned`, ASPM off, boost locked)        |
| **Secrets Integration** | Sops-nix with host ED25519 SSH key (`/persist/keys/ssh/ssh_host_ed25519_key`)       |

______________________________________________________________________

## 2. Power Management & Hardware Tuning

Workstation `yitaishi` is configured for raw throughput, zero latency spikes, and predictable real-time execution:

- **Tuned Daemon (`tuned`)**: Enforces `yitaishi-performance` profile inheriting `latency-performance`.
- **Aggressive Kernel Parameters**:
  - `pcie_aspm=off`, `pcie_port_pm=off`, `usbcore.autosuspend=-1`
  - `nvme_core.default_ps_max_latency_us=0` (zero NVMe power-state sleep latency)
  - `snd_hda_intel.power_save=0`, `amdgpu.runpm=0` (disables GPU runtime power management)
- **Runtime Performance Lock (`yitaishi-no-power-saving.service`)**:
  - Executed on boot and upon any resume event.
  - Locks CPU energy performance preference (`EPP`) to `performance`.
  - Forces CPU core boost (`cpb_boost = 1`) and AMD P-State active mode.
  - Forces AMD GPU DPM performance level to `high`.
- **GPU Overclocking / Overdrive**: `hardware.amdgpu.ppfeaturemask = "0xffffffff"` enables full clock, voltage, and fan tuning via LACT.

______________________________________________________________________

## 3. Desktop Environment & Multi-Monitor Layout

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Triple Monitor Topology                            │
├──────────────────────────┬──────────────────────────┬───────────────────────┤
│ Left Display             │ Center Display (Primary) │ Right Display         │
│ 2560x1080 @ 75Hz         │ 3840x2160 @ 120Hz        │ 1920x1080 @ 240Hz     │
│ Ultra-wide Work / Code   │ 4K High-Refresh Gaming   │ E-Sports / Monitoring │
└──────────────────────────┴──────────────────────────┴───────────────────────┘
```

- **Desktop Shells**: GNOME desktop or Niri Wayland compositor.
- **Ly Greeter**: Terminal-based display manager configured in 8-color VT framebuffer mode to prevent color mangling on Linux consoles, styled to match the Stylix base16 palette.
- **Stylix Theming**: Dark polarity base16 theme (`theme.nix`), custom fonts and cursors (`theme-assets.nix`), GTK/Qt/GRUB/Plymouth targets enabled.
- **Lan Mouse KVM**: Software KVM configured to seamlessly move cursor across the right screen boundary onto laptop `yixiaoqing`.
- **FIDO2 Authentication**: PAM U2F authentication enabled for system login and `sudo`.

______________________________________________________________________

## 4. Pro-Audio Production DAW Studio

Configured via `modules/audio/default.nix` and `modules/audio-home.nix`:

### 4.1 Real-Time Kernel & Low-Latency PipeWire

- **Musnix Integration**: Real-time audio kernel privileges, thread priority tuning, `rtcqs` system diagnostic tool.
- **PipeWire Studio Tuning**:
  - Sample Rate: **96,000 Hz** bit-perfect audio processing.
  - Quantum Buffer: **128 samples** (~1.33 ms hardware latency).
  - Realtime Kit (`rtkit`) priority boosting.

### 4.2 Production Tools & Plugin Ecosystem

- **DAWs & Sequencers**: Reaper, Carla, LMMS, Giada, Seq66, Qmidiarp, Stochas, Helio Workstation.
- **Drum Synthesis & Samplers**: MT-PowerDrumKit, DrumGizmo (with CrocellKit, DRSKit, MuldjordKit, Shkit multi-mic drumkits), AVL Drumkits.
- **Synthesizers & Processors**: Vital, Surge-XT, Helm, Odin2, Dexed, Cardinal Modular, LSP-Plugins suite, Calf Studio Gear, Dragonfly Reverb, Guitarix, ChowDSP.
- **Scaffolded Preset & Library Tree (`/home/yi`)**:
  - `~/Music/midi-library/`: ldrolez chord progressions, Magenta Groove drum MIDI, MAESTRO piano performances, Lakh clean MIDI songs.
  - `~/Audio/nam/`: Neural Amp Modeler (`.nam`) profiles.
  - `~/Audio/ir/`: Speaker cabinet and room impulse responses (`.wav`).
  - `~/Audio/reaper-fxchains/`: Custom Reaper effect chain presets.

______________________________________________________________________

## 5. Sim Racing, VR & Gaming

Configured in `hosts/yitaishi/gaming.nix` and `modules/gaming.nix`:

- **Fanatec Racing Hardware**: Kernel module and udev rules (`services.fanatec.enable = true`) for direct-drive wheelbases and pedals.
- **GameMode Integration**:
  - Automatically pauses background daemon resource contention (`coolercontrold`, `lactd`) during gaming sessions.
  - Disables GNOME Vitals extension while games are active to prevent frame drops.
- **WiVRn VR Streaming**: OpenXR / SteamVR wireless headset streaming over local network (`host.vr = true`).
- **Steam & Tools**: Steam with Proton-GE, Gamescope micro-compositor, Lutris.

______________________________________________________________________

## 6. Remote Nix Builder Role

- **High-Throughput Derivation Worker**: Configured with 16 parallel build jobs (`speedFactor = 360`).
- **Distributed Build Access**: Accepts remote build derivations from `yifuwuqi` (during CI runs) and `yixiaoqing` (laptop offload) over Tailscale on port `24212`.
- **Pinned Host Key Authentication**: Registered in `secrets/keys.nix` under `keys.hosts.yitaishi`.

______________________________________________________________________

## 7. Network & Storage Mounts

- **LAN & Mesh**: NetworkManager with `checkReversePath = "loose"`. Tailscale IP `100.69.0.4/32`, NetBird IP `100.42.0.3/16`.
- **Samba Client Automounts**:
  - `/mnt/smb/share` $\\to$ `//yifuwuqi.lan/share`
  - `/mnt/smb/the.files` $\\to$ `//yifuwuqi.lan/the.files`
  - Monitored by `smb-mounts-recover.timer` (30-second health check and auto-remount).

______________________________________________________________________

## 8. Key Source Files

- `hosts/yitaishi/configuration.nix`
- `hosts/yitaishi/services.nix`
- `hosts/yitaishi/hardware.nix`
- `hosts/yitaishi/boot.nix`
- `hosts/yitaishi/power.nix`
- `hosts/yitaishi/graphics.nix`
- `hosts/yitaishi/gaming.nix`
- `modules/audio/default.nix`
- `modules/audio-home.nix`
- `modules/desktop.nix`
- `modules/desktop/ly.nix`
- `modules/services/lan-mouse.nix`
