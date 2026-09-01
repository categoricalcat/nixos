# Host Profile: yixiaoqing (Mobile Laptop)

`yixiaoqing` is the mobile laptop workstation, designed for battery efficiency, secure roaming, hardware biometric authentication, and scrollable Wayland tiling.

______________________________________________________________________

## 1. System & Hardware Specifications

| Component               | Specification                                                                     |
| ----------------------- | --------------------------------------------------------------------------------- |
| **Role**                | Mobile Workstation, Portable Development Client                                   |
| **Architecture**        | `x86_64-linux` (Intel ThinkPad Platform)                                          |
| **GPU / Display**       | Intel Iris Xe Graphics, 2.8K OLED Display (2880x1800 @ 60Hz, 1.5x scale)          |
| **Kernel & Boot**       | Linux kernel with Intel GuC/FBC/PSR tuning; systemd-boot (limit 10)               |
| **Filesystems**         | Ext4 root (`8e1677d4-bc8f-4aa0-ba94-4a52aeead21e`), VFAT `/boot` (`3412-16F4`)    |
| **Swap & Hibernate**    | Dedicated Swap partition (`287e3d76-e122-4a82-bb39-ca2f5c42cc41`) for hibernation |
| **Power Strategy**      | TLP battery optimization, Thinkfan ACPI fan curve, Suspend-then-Hibernate         |
| **Secrets Integration** | Sops-nix with host ED25519 SSH key (`/persist/keys/ssh/ssh_host_ed25519_key`)     |

______________________________________________________________________

## 2. Power Management & Thermal Tuning

```text
┌─────────────────────────────────────────────────────────────┐
│                    yixiaoqing Power Plan                    │
├──────────────────────────────┬──────────────────────────────┤
│ AC Power                     │ Governor: performance        │
│                              │ EPP: performance             │
│                              │ CPU Max: 100%, Boost: ON     │
├──────────────────────────────┼──────────────────────────────┤
│ Battery Power                │ Governor: powersave          │
│                              │ EPP: power                   │
│                              │ CPU Max: 40%, Boost: OFF     │
├──────────────────────────────┼──────────────────────────────┤
│ Battery Health Care          │ Start Charge: 75%            │
│                              │ Stop Charge: 80%             │
├──────────────────────────────┼──────────────────────────────┤
│ Sleep & Hibernation          │ Suspend-then-Hibernate       │
│                              │ (1 hr S3 Deep Sleep -> Swap) │
└──────────────────────────────┴──────────────────────────────┘
```

Configured via `modules/services/tlp.nix` and `hosts/yixiaoqing/power.nix`:

- **TLP Power Profiles**:
  - **Battery Health**: Enforces charge thresholds (`START_CHARGE_THRESH_BAT0 = 75`, `STOP_CHARGE_THRESH_BAT0 = 80`) to extend battery lifespan.
  - **On AC**: Governor `performance`, EPP `performance`, full boost enabled, ASPM performance.
  - **On Battery**: Governor `powersave`, EPP `power`, frequency capped at 40%, boost disabled, PCIe ASPM `powersupersave`, sound power save enabled.
- **Intel i915 Kernel Optimizations**:
  - `i915.enable_guc=3`: Enables hardware GuC firmware submission and power management.
  - `i915.enable_psr=1`: Panel Self Refresh active to save power during static screen rendering.
  - `i915.enable_fbc=1`: Frame Buffer Compression active.
- **Sleep & Hibernation Pipeline**:
  - Kernel parameters: `mem_sleep_default=deep` (forces true S3 deep sleep), `acpi_osi="Windows 2020"`.
  - Logind: `HandleLidSwitch = "suspend-then-hibernate"` with `HibernateDelaySec = 3600` (suspends in low-power S3 for 60 minutes, then safely writes RAM state to swap and powers off).
- **Thermal & Scheduling Daemons**:
  - `thinkfan`: Direct ACPI fan control curve (`options thinkpad_acpi fan_control=1`).
  - `thermald`: Intel thermal throttling daemon.
  - `system76-scheduler`: Automatic CFS scheduling optimization for interactive desktop responsiveness.

______________________________________________________________________

## 3. Desktop Shell & HiDPI Configuration

- **Compositor & Shell**: Niri Wayland scrollable-tiling window manager (`programs.niri.package = pkgs.niri-unstable`) paired with Dank Material Shell (`dms`).
- **DMS Greeter**: Graphical greeter (`dms-greeter`) powered by Dank Material Shell on Niri.
- **HiDPI Scaling**: 2880x1800 display rendered at **1.5 fractional scaling** (`QT_QPA_PLATFORM = "wayland"`, `NIXOS_OZONE_WL = "1"`).
- **Stylix Theming**: Unified dark theme across Niri, GTK, Qt, and terminal utilities.
- **Lan Mouse KVM**: Seamlessly bridges mouse cursor across left screen boundary onto desktop `yitaishi`.

______________________________________________________________________

## 4. Multi-Layered Authentication & Security

```text
┌─────────────────────────────────────────────────────────────┐
│                 yixiaoqing Auth Mechanisms                  │
├──────────────────────────────┬──────────────────────────────┤
│ 1. Fingerprint (fprintd)     │ Biometric PAM auth for sudo  │
│                              │ and login                    │
├──────────────────────────────┼──────────────────────────────┤
│ 2. Physical FIDO2 (pam_u2f)  │ Hardware USB security key    │
│                              │ verification                 │
├──────────────────────────────┼──────────────────────────────┤
│ 3. TPM2-FIDO2 Virtual Token  │ Virtual FIDO2 token via      │
│                              │ TPM2 chip + /dev/uhid        │
├──────────────────────────────┼──────────────────────────────┤
│ 4. Host ED25519 Age Key      │ Decrypts Sops secrets        │
└──────────────────────────────┴──────────────────────────────┘
```

- **Fingerprint PAM Auth**: `services.fprintd.enable = true` provides fast biometric unlock.
- **Hardware FIDO2**: `security.pam.u2f` configured for interactive passwordless or dual-factor prompt.
- **TPM2 Virtual FIDO2 Token**: Configured in `modules/services/tpm-fido2.nix` to expose a hardware-backed virtual security key through Linux `uhid`.

______________________________________________________________________

## 5. Networking & Roaming Mesh

- **NetworkManager**: Handles Wi-Fi roaming with power savings enabled (`wifi.powersave = true`).
- **Tailscale with Full Traffic Tunneling**:
  - IP: `100.69.0.3/32`.
  - Configured with `exitNodeHost = "100.69.0.1"` (routes all roaming internet traffic securely through `yirukou`).
  - Tailscale SSH enabled for remote administration.
- **Samba Client Automounts**:
  - Mounts `/mnt/smb/share` and `/mnt/smb/the.files` over VPN or local LAN, monitored by `smb-mounts-recover.timer`.
- **Distributed Build Client**:
  - Offloads heavy compilation jobs to `yifuwuqi` (16 jobs) and `yitaishi` (16 jobs), keeping laptop fans silent.

______________________________________________________________________

## 6. Key Source Files

- `hosts/yixiaoqing/configuration.nix`
- `hosts/yixiaoqing/services.nix`
- `hosts/yixiaoqing/hardware.nix`
- `hosts/yixiaoqing/boot.nix`
- `hosts/yixiaoqing/power.nix`
- `hosts/yixiaoqing/networking.nix`
- `modules/desktop/niri.nix`
- `modules/desktop/greetd.nix`
- `modules/services/tlp.nix`
- `modules/services/tpm-fido2.nix`
