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

### Distributed Builds Key

The `nix-builder` SSH key is distributed to all mesh nodes via SOPS. If you need to generate a new key or set it up for the first time:

```bash
# 1. Generate the key (will create ./nix-builder-key and ./nix-builder-key.pub)
ssh-keygen -t ed25519 -f ~/.ssh/nix-builder-key

# 2. Paste the private key into SOPS under ssh/nix-builder
sudo -E sops edit /etc/nixos/secrets/distributed-builds.yaml

# 3. Update the public key variable
# Replace `builderPublicKey` in `modules/distributed-builds.nix` with the contents of `./nix-builder-key.pub`
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

### shared services htpasswd (yifuwuqi)

Shared HTTP basic-auth file used by web UIs behind nginx (Netdata today;
Prometheus/Alertmanager/Loki later). Declared in
`modules/services/shared-auth.nix` as the sops secret `services/htpasswd`.

```bash
# generate a bcrypt entry (repeat to add more users)
nix-shell -p apacheHttpd --run "htpasswd -nbB admin '<password>'"

# paste under services.htpasswd in the encrypted file
sudo -E sops edit /etc/nixos/secrets/secrets.yaml
```

Expected shape (see `secrets/.secrets.example.yaml`):

```yaml
services:
    htpasswd: |
        admin:$2y$05$...
```

Rotating the password rotates it for every service that uses this file.

### search (yifuwuqi)

`search.fufu.land` -> SearXNG (`modules/services/searxng.nix`), behind the same
`services/htpasswd` basic-auth gate. Adding a user is the same `htpasswd -nbB`
flow described above; no extra sops keys are introduced.

The signing key is generated on first boot into a stateful file outside the nix
store (rotate by deleting and restarting):

- SearXNG: `/var/lib/searx-secret/env` (`SEARXNG_SECRET=`)
