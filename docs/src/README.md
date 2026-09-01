# Fleet Documentation

This book provides the technical reference, network topologies, hosted service specifications, hardware profiles, and bootstrap runbooks for the NixOS fleet.

______________________________________________________________________

## 1. Maintained Fleet Hosts

| Host             | Primary Role                                              | IP / Network                                                                 | Hardware & Key Architecture                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Profile                                   |
| ---------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| **`yirukou`**    | Edge Router, Gateway, Reverse Proxy, Primary DNS          | LAN `10.42.0.1/24`<br/>VLAN 42 `10.42.42.1/24`<br/>Tailscale `100.69.0.1/32` | Multi-NIC Intel router. Keepalived dual WAN failover (`enp7s0`/`enp6s0`), software bridge `br0`, Kea DHCPv4, Nginx reverse proxy (ACME wildcard `*.fufu.land`), AdGuard Home + Unbound recursive DNS with remote Valkey L2 cache, Tailscale subnet router & exit node, Vector, GoAccess.                                                                                                                                                                                                          | [yirukou Profile](hosts/yirukou.md)       |
| **`yifuwuqi`**   | Core Server, DB, Monitoring, Binary Cache, AI, Media      | LAN `10.42.0.2/24`<br/>Tailscale `100.69.0.6/32`<br/>NetBird `100.42.0.2/16` | AMD Ryzen APU (Radeon 680M). PostgreSQL 18, Valkey (port 6379, DNS L2 cache), Attic binary cache pipeline (`cache.fufu.land/yi`), Forgejo Git (`git.fufu.land`) + native runner, GitHub Actions runner, Prometheus/Loki/Grafana/Vector stack, AdGuard Home + Unbound, Arr stack (Gluetun ProtonVPN), llama-cpp (Vulkan `qwen3.6-35b-abliterated:11437`), SillyTavern, SearXNG (Tor), Firecrawl (5 containers), Samba server, WebDAV, Cockpit, Homepage, Portainer, distributed builder (16 jobs). | [yifuwuqi Profile](hosts/yifuwuqi.md)     |
| **`yitaishi`**   | Workstation, Remote Builder, Pro-Audio Studio, Sim Racing | Tailscale `100.69.0.4/32`<br/>NetBird `100.42.0.3/16`                        | AMD Ryzen CPU + AMD Radeon RX 7900 XTX (gfx1100, ROCm). Btrfs `@`/`@home`, Lanzaboote Secure Boot, Zen kernel, Musnix RT kernel + PipeWire pro-audio studio (96kHz/128q), triple monitors, GNOME/Niri + Ly greeter, Fanatec racing, GameMode hooks, WiVRn VR, FIDO2 PAM, Lan Mouse KVM, Samba client, remote builder (16 jobs, speedFactor 360).                                                                                                                                                  | [yitaishi Profile](hosts/yitaishi.md)     |
| **`yixiaoqing`** | Mobile Laptop, Roaming Development Client                 | Tailscale `100.69.0.3/32`<br/>NetBird `100.42.0.4/16`                        | Intel Core CPU + Intel Iris Xe Graphics. ThinkPad i915 tuning, 2.8K HiDPI display (scale 1.5), Niri Wayland compositor + DMS shell (dms greeter), TLP battery profiles, Thinkfan ACPI fan curve, S3 deep sleep + suspend-then-hibernate, TPM2-FIDO2 virtual token + physical FIDO2 + fprintd fingerprint PAM, Lan Mouse KVM, Tailscale exit node via `yirukou`, Samba client.                                                                                                                     | [yixiaoqing Profile](hosts/yixiaoqing.md) |
| **`yichuang`**   | WSL2 Development Environment                              | Host Networking / WSL                                                        | Windows Subsystem for Linux 2 via `nixos-wsl`, developer mode, ROCm compute support, OpenSSH server (port 24212), Samba client, Home Manager profile `yijia`.                                                                                                                                                                                                                                                                                                                                     | [yichuang Profile](hosts/yichuang.md)     |

______________________________________________________________________

## 2. Source of Truth Flow

The documentation adheres strictly to a **Codebase → Documentation** flow:

- **Network Topology & Address Registry**: `modules/addresses.nix`
- **Host Hardware & Networking**: `hosts/<hostname>/`
- **Shared Service Implementations**: `modules/services/`
- **Host Service Enablement**: `hosts/<hostname>/services.nix`
- **Cryptographic Keys & Identities**: `secrets/keys.nix`
- **User Configurations & Dotfiles**: `users/`

______________________________________________________________________

## 3. Quick Navigation

- **Fleet Hosts**: [yirukou](hosts/yirukou.md) · [yifuwuqi](hosts/yifuwuqi.md) · [yitaishi](hosts/yitaishi.md) · [yixiaoqing](hosts/yixiaoqing.md) · [yichuang](hosts/yichuang.md)
- **Networking**: [yirukou Router](networking/yirukou.md) · [Sysctl & Firewall](networking/sysctl-firewall.md) · [Tailscale Subnet Forwarding](networking/tailscale-subnet-forwarding.md) · [Unbound Architecture](networking/unbound-integration.md)
- **Core Infrastructure**: [Secrets Management](services/secrets.md) · [DNS & Reverse Proxy](services/dns-and-proxy.md) · [Monitoring Stack](services/monitoring.md) · [AI-SSH Restricted Lane](services/ai-ssh.md)
- **Applications & Storage**: [Hosted Services Directory](services/hosted-services.md) · [Arr Stack](services/arr-stack.md) · [File Sharing (Samba/WebDAV)](services/file-sharing.md) · [AI & Local Inference](services/ai-rocm.md)
- **Nix Mesh & CI/CD**: [Nix Build & Cache Mesh](services/nix-build-cache.md) · [CI/CD Pipeline](services/ci-cd.md) · [CI & Binary Cache Bootstrap](services/ci-cache.md)
- **Hardware & Workstation**: [Bootstrap Runbook](hardware/bootstrap-runbook.md) · [Hardware Authentication](hardware/bootstrap.md) · [Software KVM (Lan Mouse)](hardware/lan-mouse.md) · [USB Boot Delays](hardware/usb-boot-delays.md) · [Pro-Audio Drums](audio/drums.md)
