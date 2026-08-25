# Host Profile: yichuang (WSL2 Development Node)

`yichuang` provides a native NixOS development environment running inside Windows Subsystem for Linux 2 (WSL2) on the primary Windows workstation.

______________________________________________________________________

## 1. System & Architecture Specifications

| Component                  | Specification                                                      |
| -------------------------- | ------------------------------------------------------------------ |
| **Role**                   | Windows-hosted Linux Development Environment, GPU Compute Client   |
| **Architecture**           | `x86_64-linux` (WSL2 Hypervisor)                                   |
| **WSL Integration**        | `nixos-wsl` flake module (`inputs.nixos-wsl.nixosModules.default`) |
| **Compute / Acceleration** | AMD ROCm support enabled (`rocmSupport = true`)                    |
| **Default User**           | `yi` (with Home Manager profile `yijia`)                           |
| **Secrets Integration**    | Sops-nix integration with host ED25519 SSH key                     |

______________________________________________________________________

## 2. Environment Configuration

### 2.1 NixOS-WSL Configuration

Configured in `hosts/yichuang/configuration.nix`:

- `wsl.enable = true`: Integrates with the Windows host, interop with Windows binaries, and environment variable synchronization.
- `wsl.defaultUser = "yi"`: Boots directly into the unprivileged developer shell.
- `wsl.startMenuLaunchers = true`: Generates Windows start menu shortcuts for installed GUI and CLI applications.
- `host.developer = true`: Equips the environment with the complete suite of Nix development tools, Rust toolchains, linters, and formatters.

### 2.2 Remote Access & File Sharing

- **OpenSSH Server**: Runs on custom port `24212` with standard locked-down authentication settings.
- **Samba Client**: Mounts shared storage paths from `yifuwuqi` over local or mesh networking.
- **Attic Cache Client**: Pre-configured to pull cached binary closures from `cache.fufu.land/yi`.

______________________________________________________________________

## 3. CI Matrix Build Target

`yichuang` is included in the `.forgejo/workflows/flake-ci.yml` build matrix, ensuring that the WSL2 system closure is continuously evaluated, built, and pushed to the Attic binary cache on every commit.

______________________________________________________________________

## 4. Key Source Files

- `hosts/yichuang/configuration.nix`
- `hosts/yichuang/services.nix`
- `hosts/yichuang/addresses.nix`
- `users/home/yijia.nix`
