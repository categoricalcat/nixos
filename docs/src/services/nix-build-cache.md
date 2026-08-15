# Nix Build Host And Mesh

This guide teaches you how to add a new host to the distributed build mesh. It covers
registering the host, authenticating it via SSH host keys, and running builds against
the mesh.

## How The Mesh Works (in one paragraph)

One machine (by convention `yifuwuqi`) acts as the primary build host. Clients ask it
to build their system closures; it may offload derivation work to configured remote
builders (`yitaishi`). Built paths flow back over SSH — no separate binary cache service
needed for day-to-day switching.

For the CI path that mirrors GitHub into Forgejo, builds with Forgejo Actions, and
pushes results to Attic, see [CI and Binary Cache](ci-cache.md).

## Add A New Host — Step By Step

### Step 1: Register the host in `modules/addresses.nix`

Add an entry under `hosts.yifuwuqi.distributed-builds`. The shape is:

```nix
# modules/addresses.nix — inside the existing distributed-builds list
{
  host = "yixiaoqing";
  hostName = "yixiaoqing.lan";
  publicKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTV...";
  systems = ["x86_64-linux" "aarch64-linux"];
  sshUser = "yi";
  remoteBuilder = true;  # false = client-only, true = both builds and accepts remote work
}
```

| Field | Purpose |
|---|---|
| `host` | Short name used in `--build-host` |
| `hostName` | FQDN or IP reachable from the mesh |
| `publicKey` | Base64-encoded SSH host key (see Step 2) |
| `systems` | What architectures this host can build |
| `sshUser` | User that Nix connects as on this host (must be in `nix.trustedUsers`) |
| `remoteBuilder` | `true` to also receive derivations from other hosts |

### Step 2: Register the SSH host key in `secrets/keys.nix`

Run this on the new host to get its SSH host key:

```bash
cat /persist/keys/ssh/ssh_host_ed25519_key.pub
# or if /persist does not exist yet:
cat /etc/ssh/ssh_host_ed25519_key.pub
```

The output looks like:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...
```

Open `secrets/keys.nix` and add the key under the host's attribute:

```nix
# secrets/keys.nix — add inside the keys attrset
yixiaoqing = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
```

### Step 3: Decide the host's role

| Set `remoteBuilder` to… | If the host… |
|---|---|
| `false` (client-only) | Is a laptop, VM, or low-power machine that should build locally but never be asked to build for others |
| `true` | Has ample CPU/RAM and should both build locally and accept remote work from `yifuwuqi` |

The topology of the current mesh (for reference, not for copy-paste):

| Host | Role | Remote builders it uses |
|---|---|---|
| `yifuwuqi` | primary build host | `yitaishi` |
| `yitaishi` | remote builder | `yifuwuqi` |
| `yixiaoqing` / `yirukou` | client-only | `yifuwuqi`, `yitaishi` |

### Step 4: Deploy

```bash
nixos-rebuild switch --flake .#your-new-host --target-host yi@your-new-host --use-remote-sudo
```

### Step 5: Verify

On the new host, confirm it can reach the mesh:

```bash
nix store ping --store ssh-ng://yi@yifuwuqi
```

Or run a build from outside:

```bash
nixos-rebuild switch \
  --flake .#your-new-host \
  --build-host yi@yifuwuqi \
  --target-host yi@your-new-host \
  --use-remote-sudo
```

### Builder SSH Keys (how it works)

Each host authenticates to remote builders using its own SSH host key at
`/persist/keys/ssh/ssh_host_ed25519_key`. Authorized client keys come from
`secrets/keys.nix`. There is no shared builder keypair — rotating a key is the same
as rotating the host's SSH host key. No Nix binary-cache signing key is needed;
the SSH transport carries built paths back to the requester.

Host keys are now **pinned**, not TOFU'd: `modules/services/ssh/known-hosts.nix`
regenerates `/etc/ssh/ssh_known_hosts` from `secrets/keys.nix` ×
`modules/addresses.nix` (bare names, `.lan`/`.local`/`.ts`/`.nb` aliases, and
IPs), and the ssh client config uses `StrictHostKeyChecking yes`. When a host's
key changes, update `secrets/keys.nix` before switching, or connections to that
host will be refused.

## Build Locally, Switch Locally

From the host you want to switch, ask `yifuwuqi` to build and then copy the
completed system closure back for activation:

```bash
sudo nixos-rebuild switch \
  --flake .#yixiaoqing \
  --build-host yi@yifuwuqi
```

Use the target host's flake attribute, for example `.#yitaishi` when switching
`yitaishi`.

If SSH config already supplies the remote user, `--build-host yifuwuqi` is
equivalent. The build user on `yifuwuqi` must be trusted by the Nix daemon.

## Build And Deploy Remotely

From a third machine, build on `yifuwuqi` and deploy to another host:

```bash
nixos-rebuild switch \
  --flake .#yixiaoqing \
  --build-host yi@yifuwuqi \
  --target-host yi@yixiaoqing \
  --use-remote-sudo
```

If remote sudo needs an interactive password prompt, run with:

```bash
NIX_SSHOPTS="-o RequestTTY=force" nixos-rebuild switch \
  --flake .#yixiaoqing \
  --build-host yi@yifuwuqi \
  --target-host yi@yixiaoqing \
  --use-remote-sudo
```

## Source Of Truth

| If you need to… | Edit this file |
|---|---|
| Add, remove, or change a host's role | `modules/addresses.nix` (the `distributed-builds` list) |
| Tweak how Nix schedules remote builders (max jobs, speed factor) | `modules/distributed-builds.nix` |
| Register or remove a host's SSH key | `secrets/keys.nix` |
