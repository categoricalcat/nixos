---
name: nixos
description: NixOS configuration, modules, options, and flake management. Read local source code from /etc/nix/inputs before searching online. Always verify which host you are on.
---

# NixOS AI Skill

When reasoning about NixOS configurations, modules, or options, you must strictly follow these instructions:

## 1. Identify the Current Host

Verify which host the local workspace is running on once at the start of a session if unknown (e.g. by running `hostname`). Do not assume hostnames, but do **not** repeatedly run `hostname` before every single command or when executing explicit cross-host commands like `ai-ssh <host>`.

Each host's configuration lives under `hosts/<hostname>/configuration.nix` in the flake. Make sure any NixOS commands (e.g. `nixos-rebuild`, reading hardware config, checking services) target the **correct host**.

If you are connected remotely and need to modify a *different* host's configuration, clearly state which host you are editing for and do **not** run deployment commands meant for a different host.

## 1.5 Cross-Host Access (read-only)

To inspect *another* mesh host (systemd status, journal, files), use the
sanctioned lane: `ai-ssh <host> <command>` — a read-only gate enforced on the
server (see `docs/src/services/ai-ssh.md`).

- Never raw `ssh`, `scp`, `sshfs`, `mosh`, `rsync`.
- Never `nixos-rebuild --target-host` / `--build-host` — hand the command to
  the user instead.
- `ai-ssh` is deployed on all mesh hosts and is the only sanctioned lane for
  cross-host reads — use it directly with the target command without redundant hostname checks.

## 2. Read Local Source Code First

Always search for and read the source code in the local flake inputs folder, which is located at `/etc/nix/inputs`.

## 3. Understand the Local Inputs

The `/etc/nix/inputs` directory contains the exact source code for the flake inputs (such as `nixpkgs`, `home-manager`, `stylix`, etc.) that are mapped and currently in use by the system.

## 4. Fallback to Online Sources

If the relevant source code or documentation is not found in `/etc/nix/inputs`, only then should you search for the source code online.

## 5. Do Not Make Assumptions

Never make assumptions about NixOS options, module structures, function signatures, or implementation details. Always verify the truth by reading the actual source code.
