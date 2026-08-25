# Hardware Bootstrap

This page contains imperative setup steps for hardware features that cannot be entirely declarative.

## FIDO2 Authentication

To enable YubiKey or other FIDO2 tokens for system authentication (PAM):

```bash
mkdir -p ~/.config/Yubico
nix-shell -p pam_u2f --run "pamu2fcfg > ~/.config/Yubico/u2f_keys"
```

> *Note, for multiple keys, append instead of overwrite: `pamu2fcfg -n >> ~/.config/Yubico/u2f_keys`.*

## Secure Boot (Lanzaboote) on `yitaishi`

To enroll Secure Boot keys on `yitaishi` while preserving dual-boot compatibility with Windows:

```bash
# if Windows uses BitLocker, save the recovery key first
sudo sbctl create-keys
sudo nixos-rebuild switch --flake .#yitaishi

# put firmware into Secure Boot Setup Mode, then:
sudo sbctl enroll-keys --microsoft

# verify
bootctl status
sudo sbctl verify
```

> *Use `--microsoft` to keep the usual Windows and firmware signing chain available.*

## Bitwarden System Auth + Keyring

**Verify prerequisites after `nixos-rebuild switch`:**

```bash
# polkit policy is registered
pkaction --action-id com.bitwarden.Bitwarden.unlock

# gnome-keyring exposes Secret Service on D-Bus
busctl --user list | grep -i secret

# polkit agent is running (niri only; GNOME uses gnome-shell's built-in agent)
pgrep -a polkit
```
