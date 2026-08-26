# Summary

[Overview](README.md)

# Fleet & Architecture

- [Fleet Hosts](<>)
  - [yirukou (Edge Router & Gateway)](hosts/yirukou.md)
  - [yifuwuqi (Core Server & Services)](hosts/yifuwuqi.md)
  - [yitaishi (Workstation & Studio)](hosts/yitaishi.md)
  - [yixiaoqing (Mobile Laptop)](hosts/yixiaoqing.md)
  - [yichuang (WSL2 Development)](hosts/yichuang.md)
- [Networking & Perimeter](<>)
  - [yirukou Router & Edge](networking/yirukou.md)
  - [Sysctl and Firewall Hardening](networking/sysctl-firewall.md)
  - [Tailscale Subnet Forwarding](networking/tailscale-subnet-forwarding.md)
  - [Unbound Recursive DNS & L2 Cache](networking/unbound-integration.md)

# Services & Infrastructure

- [Core Infrastructure & Access](<>)
  - [Secrets and Host Keys](services/secrets.md)
  - [DNS and Reverse Proxy](services/dns-and-proxy.md)
  - [Monitoring & Observability](services/monitoring.md)
  - [AI-SSH Restricted Remote Access](services/ai-ssh.md)
- [Hosted Applications & Storage](<>)
  - [Hosted Web Services Directory](services/hosted-services.md)
  - [Arr & Media Stack Setup](services/arr-stack.md)
  - [File Sharing (Samba & WebDAV)](services/file-sharing.md)
  - [AI & Local Inference](services/ai-rocm.md)
- [Nix Mesh & CI/CD](<>)
  - [CI/CD Pipeline & Runners](services/ci-cd.md)
  - [Nix Build Mesh & Binary Cache](services/nix-build-cache.md)
  - [CI & Binary Cache Bootstrap](services/ci-cache.md)

# Hardware & Workstation

- [Hardware & Provisioning](<>)
  - [Fleet Provisioning Runbook](hardware/bootstrap-runbook.md)
  - [Hardware Authentication & Tokens](hardware/bootstrap.md)
  - [Software KVM (Lan Mouse)](hardware/lan-mouse.md)
  - [Troubleshooting USB Boot Delays](hardware/usb-boot-delays.md)
- [Studio & Audio](<>)
  - [Pro-Audio Drum Kits](audio/drums.md)
