# Hardware Authentication & Token Bootstrap

This page provides the imperative initialization steps for biometric, hardware security token, and Secure Boot features across the fleet.

______________________________________________________________________

## 1. Physical FIDO2 / U2F Authentication (`pam_u2f`)

Configured via `modules/fido2.nix` for hardware security keys (YubiKey, SoloKey, Nitrokey):

### 1.1 Enrolling Primary Key

```bash
mkdir -p ~/.config/Yubico
nix-shell -p pam_u2f --run "pamu2fcfg > ~/.config/Yubico/u2f_keys"
```

### 1.2 Enrolling Backup Keys (Append Mode)

```bash
pamu2fcfg -n >> ~/.config/Yubico/u2f_keys
```

______________________________________________________________________

## 2. Biometric Fingerprint Enrollment (`fprintd`)

Active on `yixiaoqing` via `services.fprintd.enable = true`:

```bash
# Enroll right index finger
fprintd-enroll

# Verify enrollment
fprintd-verify
```

______________________________________________________________________

## 3. TPM2 Virtual FIDO2 Token (`modules/services/tpm-fido2.nix`)

Active on `yixiaoqing` to expose a hardware-backed virtual security key through Linux `uhid`:

```bash
# Verify the tpm-fido2 daemon is active
systemctl status tpm-fido2.service

# Verify virtual token device creation
ls -l /dev/uhid
```

______________________________________________________________________

## 4. Lanzaboote Secure Boot Enrollment (`yitaishi`)

Active on `yitaishi` via `boot.lanzaboote.enable = true`:

```bash
# 1. Generate Secure Boot keys (one-time)
sudo sbctl create-keys

# 2. Build and switch to the Lanzaboote generation
sudo nixos-rebuild switch --flake .#yitaishi

# 3. Reboot into UEFI Firmware Setup -> Set Secure Boot to "Setup Mode"
# 4. Enroll keys with Microsoft certs preserved (for dual-boot/GPU firmware compatibility)
sudo sbctl enroll-keys --microsoft

# 5. Verify enrollment and EFI binary signatures
bootctl status
sudo sbctl verify
```

______________________________________________________________________

## 5. Bitwarden System Auth & Keyring Verification

Verify D-Bus Secret Service and Polkit integrations:

```bash
# 1. Verify Polkit policy is registered
pkaction --action-id com.bitwarden.Bitwarden.unlock

# 2. Verify gnome-keyring exposes Secret Service on D-Bus
busctl --user list | grep -i secret

# 3. Verify Polkit agent is running (polkit-gnome on Niri, built-in on GNOME)
pgrep -a polkit
```
