# Nix Build Host And Mesh

The preferred workflow is to use `yifuwuqi` as the build host for NixOS
switches. `yifuwuqi` initiates the build, may offload derivations to its
configured remote builders, and keeps the resulting store paths because it was
the requester.

This avoids a separate cache service and post-build upload hook.

## Build Mesh

`modules/distributed-builds.nix` builds its remote builder list from `modules/addresses.nix`.

Each machine can always build locally. Remote builders are restricted to hosts with `nixBuild.remoteBuilder = true`:

| Host | Local builds | Remote builders used |
| --- | --- | --- |
| `yifuwuqi` | yes | `yitaishi` |
| `yitaishi` | yes | `yifuwuqi` |
| `yixiaoqing` | yes | `yifuwuqi`, `yitaishi` |
| `yirukou` | yes | `yifuwuqi`, `yitaishi` |

`yixiaoqing` and `yirukou` participate in distributed builds as clients and local builders, but they are not advertised as remote builders for the other hosts.

When `yifuwuqi` is used as `--build-host`, the build runs on `yifuwuqi` and any
remote builders `yifuwuqi` can use. With the current topology, that means
`yifuwuqi` plus `yitaishi`.

```mermaid
flowchart LR
  clientHost["Client host"] -->|"requests build"| yifuwuqi["yifuwuqi build host"]
  yifuwuqi -->|"may offload derivations"| yitaishi["yitaishi remote builder"]
  yitaishi -->|"built paths return"| yifuwuqi
  yifuwuqi -->|"system closure copied back"| clientHost
  clientHost -->|"activates switch"| activeSystem["New system"]
```

## Builder SSH Key

The `nix-builder` SSH key is shared through `/etc/nixos/secrets/distributed-builds.yaml`:

```yaml
ssh:
  nix-builder: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
    -----END OPENSSH PRIVATE KEY-----
```

This key is used for:

- `ssh-ng` remote builders in `nix.buildMachines`.
- Copying remote builder results back to the requesting build host.

It is an OpenSSH key for SSH transport. No Nix binary-cache signing key is
needed for this workflow.

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

- Builder topology: `modules/addresses.nix`
- Distributed build wiring: `modules/distributed-builds.nix`
- Secret shape example: `secrets/.distributed-builds.example.yaml`
