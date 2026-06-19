---
name: nixos
description: NixOS configuration, modules, options, and flake management. Read local source code from /etc/nix/inputs before searching online.
---

# NixOS AI Skill

When reasoning about NixOS configurations, modules, or options, you must strictly follow these instructions:

1. **Read Local Source Code First**: Always search for and read the source code in the local flake inputs folder, which is located at `/etc/nix/inputs`.
2. **Understand the Local Inputs**: The `/etc/nix/inputs` directory contains the exact source code for the flake inputs (such as `nixpkgs`, `home-manager`, `stylix`, etc.) that are mapped and currently in use by the system.
3. **Fallback to Online Sources**: If the relevant source code or documentation is not found in `/etc/nix/inputs`, only then should you search for the source code online.
4. **Do Not Make Assumptions**: Never make assumptions about NixOS options, module structures, function signatures, or implementation details. Always verify the truth by reading the actual source code.
