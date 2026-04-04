# 伊的flake

my allegedly pure configs

## the stuff

- **yitaishi**: main desktop
- **yixiaoqing**: laptop
- **yifuwuqi**: monolith server
- **yichuang**: wsl

## the imperatives

### sops

```bash
nix-shell -p ssh-to-age --run \
  'ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key > /etc/nixos/secrets/key.txt'
  
# public key (for .sops.yaml):
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
```

### samba server

```bash
nix-shell -p samba --run "sudo smbpasswd -a yi"
```

> *see `.sops.example.yaml` and `secrets/.secrets.example.yaml` for the expected formats.*

### FIDO2 Authentication

```bash
mkdir -p ~/.config/Yubico
nix-shell -p pam_u2f --run "pamu2fcfg > ~/.config/Yubico/u2f_keys"
```

> *Note, multiple keys: `pamu2fcfg -n >> ~/.config/Yubico/u2f_keys`.*

### yitaishi Lanzaboote / Windows

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

### Bitwarden System Auth + Keyring

**Verify prerequisites after `nixos-rebuild switch`:**

```bash
# polkit policy is registered
pkaction --action-id com.bitwarden.Bitwarden.unlock

# gnome-keyring exposes Secret Service on D-Bus
busctl --user list | grep -i secret

# polkit agent is running (niri only; GNOME uses gnome-shell's built-in agent)
pgrep -a polkit
```
