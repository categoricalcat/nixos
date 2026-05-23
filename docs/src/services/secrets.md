# Secrets And Host Keys

This repository assumes impermanence hosts keep private runtime identity under
`/persist/keys`. Nix does not copy or generate these files during activation:
set them up intentionally before switching to a configuration that depends on
them.

Public key metadata lives in `secrets/keys.nix`. Private keys and encrypted
SOPS payloads stay outside the Nix store.

## Runtime Layout

```text
/persist/keys/
  ssh/
    ssh_host_ed25519_key
    ssh_host_ed25519_key.pub
  sops/
    secrets.yaml
    key.txt              # temporary fallback for hosts with null recipients
```

Create the directories before the first switch:

```bash
sudo install -d -m 0700 -o root -g root /persist/keys/ssh
sudo install -d -m 0750 -o root -g root /persist/keys/sops
```

## Host SSH Identity

If the host already has an SSH identity that clients trust, copy it. This keeps
the SSH host fingerprint stable:

```bash
sudo install -m 0600 -o root -g root \
  /etc/ssh/ssh_host_ed25519_key \
  /persist/keys/ssh/ssh_host_ed25519_key

sudo ssh-keygen -y -f /persist/keys/ssh/ssh_host_ed25519_key \
  | sudo tee /persist/keys/ssh/ssh_host_ed25519_key.pub >/dev/null
sudo chown root:root /persist/keys/ssh/ssh_host_ed25519_key.pub
sudo chmod 0644 /persist/keys/ssh/ssh_host_ed25519_key.pub
```

For a fresh host with no identity to preserve, generate the key explicitly:

```bash
sudo ssh-keygen -t ed25519 -N '' \
  -f /persist/keys/ssh/ssh_host_ed25519_key
```

## Register The Host

Derive the host's age recipient from its public SSH host key:

```bash
nix-shell -p ssh-to-age --run \
  'ssh-to-age -i /persist/keys/ssh/ssh_host_ed25519_key.pub'
```

Derive yi's admin age recipient from yi's public user key:

```bash
nix-shell -p ssh-to-age --run \
  'ssh-to-age -i ~/.ssh/id_ed25519.pub'
```

Then update:

- `secrets/keys.nix`: add the host SSH public key and derived age recipient.
- `.sops.yaml`: add the derived age recipient to the relevant creation rule.

Registering a host's SSH public key here also authorizes it as a build-mesh
client, because `modules/distributed-builds.nix` reads from the same registry.

Hosts with `null` entries in `secrets/keys.nix` are not ready for the final
direct SSH-host-key decryption path. Until their recipient is registered, they
must keep the legacy age key at `/persist/keys/sops/key.txt`.

Keep the legacy recipient in `.sops.yaml` until every host has a durable SSH age
recipient and has switched successfully.

## Install Encrypted Payloads

Copy the encrypted files into the runtime path after they are rekeyed:

```bash
sudo install -m 0640 -o root -g root \
  secrets/secrets.yaml \
  /persist/keys/sops/secrets.yaml
```

Do not place private keys in the repo. The repo keeps examples, Nix wiring, and
public key metadata only.

If the host still has a `null` age recipient in `secrets/keys.nix`, install the
legacy age key as a temporary fallback:

```bash
sudo install -m 0600 -o root -g root \
  /etc/nixos/secrets/key.txt \
  /persist/keys/sops/key.txt
```

## Rekey Safely

Run `sops updatekeys` against the encrypted files. It updates recipient metadata
and must not be replaced with commands that print decrypted YAML.

Using the legacy age key during rollout:

```bash
SOPS_AGE_KEY_FILE=/etc/nixos/secrets/key.txt \
  nix-shell -p sops --run 'sops updatekeys -y secrets/secrets.yaml'
```

Using the durable SSH host key on a provisioned host:

```bash
SOPS_AGE_SSH_PRIVATE_KEY_FILE=/persist/keys/ssh/ssh_host_ed25519_key \
  nix-shell -p sops --run 'sops updatekeys -y secrets/secrets.yaml'
```

After rekeying, copy the encrypted payloads into `/persist/keys/sops/`.

## Distributed Builds Key

The build mesh uses each host's own SSH host key as its `nix-builder`
client identity. There is no shared builder keypair and no SOPS file for it.

- Private side: `nix-daemon` reads `/persist/keys/ssh/ssh_host_ed25519_key`
  (already root-only) when connecting to remote builders.
- Public side: the `nix-builder` user on each builder authorizes every
  registered `hosts.<name>.sshPublicKey` from `secrets/keys.nix`.

Rotation is the same as rotating that host's SSH host key. Adding a new host to
the build mesh just means registering its public key in `secrets/keys.nix`.

## Shared Services Htpasswd (yifuwuqi)

Shared HTTP basic-auth file used by web UIs behind nginx (Netdata today;
Prometheus/Alertmanager/Loki later). Declared in
`modules/services/shared-auth.nix` as the sops secret `services/htpasswd`.

```bash
# generate a bcrypt entry (repeat to add more users)
nix-shell -p apacheHttpd --run "htpasswd -nbB admin '<password>'"

# paste under services.htpasswd in the encrypted file
sudo -E sops edit /persist/keys/sops/secrets.yaml
```

Expected shape (see `secrets/.secrets.example.yaml`):

```yaml
services:
    htpasswd: |
        admin:$2y$05$...
```

Rotating the password rotates it for every service that uses this file.

## Search (yifuwuqi)

`search.fufu.land` -> SearXNG (`modules/services/searxng.nix`), behind the same
`services/htpasswd` basic-auth gate. Adding a user is the same `htpasswd -nbB`
flow described above; no extra sops keys are introduced.

The signing key is generated on first boot into a stateful file outside the
Nix store (rotate by deleting and restarting):

- SearXNG: `/var/lib/searx-secret/env` (`SEARXNG_SECRET=`)

## Verification Checklist

Before rebooting or removing any legacy recipient:

- `/persist/keys/ssh/ssh_host_ed25519_key` exists and is `0600 root:root`.
- `ssh-keygen -y -f /persist/keys/ssh/ssh_host_ed25519_key` matches the host
  public key in `secrets/keys.nix`.
- `ssh-to-age -i /persist/keys/ssh/ssh_host_ed25519_key.pub` matches the host
  age recipient in `secrets/keys.nix` and `.sops.yaml`.
- `/persist/keys/sops/secrets.yaml` exists on hosts that need it.
- `nixos-rebuild dry-activate --flake .#<host>` or an equivalent evaluation
  succeeds.
- SSH host fingerprints are expected after switching.
- SOPS secrets install successfully during activation.

Only remove `key.txt` fallback usage and the legacy age recipient after every
host passes this checklist.
