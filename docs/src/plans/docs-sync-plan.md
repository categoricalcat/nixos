# Fleet Documentation & Codebase Synchronization Plan

## Objective

Synchronize the mdBook documentation under `docs/src/` with the current reality of the NixOS codebase (`flake.nix`, `hosts/`, `modules/`, `users/`, `secrets/`). The documentation must accurately reflect the live configuration, system roles, network topologies, hardware profiles, running services, and bootstrap procedures across the entire fleet (`yirukou`, `yifuwuqi`, `yitaishi`, `yixiaoqing`, `yichuang`, and Home Manager profiles `yi` / `yijia`).

Additionally, eliminate all `mermaid` blocks across the documentation and plan files, replacing them with universal Unicode box-drawing architecture diagrams that render reliably in terminals, plain text, editors, and mdBook without external dependencies.

______________________________________________________________________

## Current State

A complete audit of 70+ files in the codebase revealed the following discrepancies in existing documentation:

1. **Exit Node Inversion**: `docs/src/networking/yirukou.md` states that `yifuwuqi` uses `yirukou` as its exit node. In code, `yifuwuqi` has `exitNodeHost = null;` while `yixiaoqing` (laptop) is configured with `exitNodeHost = "100.69.0.1"`.
1. **Active AI Model & Serving**: `docs/src/services/ai-rocm.md` describes `qwen2.5:7b` on port `11436`. The codebase has migrated to `qwen3.6-35b-abliterated` on port `11437` (IQ2_M quantization, Vulkan backend on Radeon 680M APU, 16k context, FlashAttention, Q8 KV cache), with SillyTavern web companion running under dedicated user `sillytavern` at `sillytavern.fufu.land`.
1. **Log Shipping Engine**: Docs refer to Promtail; `modules/services/monitoring/promtail.nix` now deploys **Vector** (`services.vector`) to ship systemd journal logs to central Loki.
1. **Binary Cache Pipeline**: `docs/src/plans/cache.md` references Harmonia; the deployed architecture uses **Attic** (server on `yifuwuqi`, `attic-watch-store`, and `attic-closure-keeper`).
1. **Missing Host Profiles**: Individual host profiles (`docs/src/hosts/*.md`) do not exist for the 5 machines in the fleet.
1. **Missing Infrastructure Documentation**: Gateway failover (Keepalived VRRP + `wan-check`/`wan-notify`), IPv6 Gai precedence, sinkhole nftables table, restricted AI SSH gate (`ai-gate.sh`), Firecrawl 5-container Podman stack, SearXNG Tor SOCKS5 integration, Kea DHCP dual-scope setup, and Forgejo/GitHub Actions CI runners are undocumented.
1. **Diagram Rendering Failure**: Six ```` ```mermaid ```` blocks across `docs/src/plans/` do not render in terminal viewers or standard markdown tools.

______________________________________________________________________

## Decisions

1. **Strict Codebase → Documentation Flow**: Source of truth is 100% extracted from Nix files. No code modifications are made during documentation updates.
1. **Universal Unicode Box-Drawing**: All diagrams are converted to standard Unicode box characters (`┌─┐`, `│`, `└─┘`, `──►`, `▲`, `▼`, `◄──►`) in fenced `text` blocks.
1. **Dedicated Host Profiles**: Create `docs/src/hosts/{yirukou,yifuwuqi,yitaishi,yixiaoqing,yichuang}.md` detailing hardware specs, network interfaces, power profiles, bootloaders, and service assignments.
1. **Consolidated Bootstrap Runbook**: Create `docs/src/hardware/bootstrap-runbook.md` with step-by-step imperative bootstrap commands (`setup-sops.sh`, `keys.nix`, `generate-sops-yaml.nix`, disk partitioning, Lanzaboote, FIDO2/U2F, fprintd, service initializations).
1. **Comprehensive Service References**: Update all service docs (`hosted-services.md`, `dns-and-proxy.md`, `nix-build-cache.md`, `file-sharing.md`, `ai-rocm.md`, `monitoring.md`, `ci-cd.md`).

______________________________________________________________________

## Phases

### Phase 1: Convert Mermaid Diagrams to Unicode Box Art

Replace all 6 ```` ```mermaid ```` blocks with Unicode box-drawing diagrams across:

- `docs/src/plans/audio-midi-presets.md` (1 diagram)
- `docs/src/plans/deploy-nixos-builds-plan.md` (2 diagrams)
- `docs/src/plans/mtls-architecture-plan.md` (2 diagrams)
- `docs/src/plans/service-security-architecture-plan.md` (1 diagram)

### Phase 2: Create Host Profile Documents

Author complete host profiles:

- `docs/src/hosts/yirukou.md` — Multi-NIC router, dual-WAN failover, bridge `br0`, VLAN 42, Kea DHCPv4, Nginx reverse proxy (~20 vhosts), AdGuard Home + Unbound, Tailscale "both" mode, Vector, GoAccess.
- `docs/src/hosts/yifuwuqi.md` — AMD APU server, dual NIC (`eno1`/`enp4s0`), PostgreSQL 18, Valkey, Attic server/watch-store/closure-keeper, Forgejo + runners, Prometheus/Loki/Grafana, Arr stack (Gluetun VPN), llama-cpp Vulkan (`qwen3.6-35b-abliterated`), SillyTavern, SearXNG (Tor), Firecrawl (5 containers), WebDAV, Cockpit, Homepage, Samba server.
- `docs/src/hosts/yitaishi.md` — Workstation (RX 7900 XTX, triple monitors), Btrfs `@`/`@home`, Lanzaboote Secure Boot, Zen kernel, Musnix RT kernel + PipeWire pro audio, Fanatec racing, GameMode hooks, WiVRn VR, FIDO2 PAM, Lan Mouse, remote builder.
- `docs/src/hosts/yixiaoqing.md` — Laptop (Intel Iris Xe, 2.8K HiDPI), Niri + Noctalia shell (tuigreet), TLP, Thinkfan, S3 deep sleep, TPM2-FIDO2 + fprintd, Lan Mouse, Tailscale exit node via `yirukou`.
- `docs/src/hosts/yichuang.md` — WSL2 environment, NixOS-WSL, ROCm compute, OpenSSH, Home Manager `yijia`.

### Phase 3: Update and Create Service Documentation

- `docs/src/services/hosted-services.md` — Full documentation of all 11 hosted web services on `yifuwuqi`.
- `docs/src/services/dns-and-proxy.md` — Dual DNS pipeline (AGH → Unbound → Valkey L2 with SWR) + Nginx reverse proxy.
- `docs/src/services/nix-build-cache.md` — Distributed build topology, pinned host keys, Attic integration.
- `docs/src/services/file-sharing.md` — Samba server shares, client automounts, 30s recovery timer.
- `docs/src/services/ai-rocm.md` — Vulkan backend, active model `qwen3.6-35b-abliterated:11437`, models registry, SillyTavern, Firecrawl MCP.
- `docs/src/services/monitoring.md` — Prometheus, Grafana (PostgreSQL-backed, declarative dashboards), Loki, Vector, exporter topology.
- `docs/src/services/ci-cd.md` — Forgejo CI workflow (`flake-ci.yml`), GitHub runner, `ci/build.sh` remote builder probing, Forgejo runner.
- `docs/src/networking/yirukou.md` — Fix exit node note, document bridge, VLAN 42, Kea DHCP, WAN failover, bogon filtering.
- `docs/src/networking/unbound-integration.md` — Active architecture reference for Unbound + Valkey L2 cache and control socket.

### Phase 4: Bootstrap Runbook & Navigation

- `docs/src/hardware/bootstrap.md` — Authentication and token enrollment (FIDO2, TPM2, fprintd, Lanzaboote, Bitwarden).
- `docs/src/hardware/bootstrap-runbook.md` — Complete end-to-end host onboarding runbook.
- `docs/src/README.md` — Fleet summary table with complete roles, IPs, and hardware.
- `docs/src/SUMMARY.md` — Full navigation structure linking all host profiles, networking, services, hardware, and plans.

### Phase 5: Verification & Build

- Verify mdBook build succeeds with zero errors: `nix shell nixpkgs#mdbook -c mdbook build docs`.
- Verify all links in `SUMMARY.md` resolve to valid files.
- Verify zero ```` ```mermaid ```` blocks remain in `docs/`.

______________________________________________________________________

## Rollout Order

1. **Step 1**: Convert all Mermaid blocks to Unicode box-drawing in the 4 plan files.
1. **Step 2**: Write the 5 host profile markdown files in `docs/src/hosts/`.
1. **Step 3**: Update existing service documentation files and create `docs/src/services/ci-cd.md`.
1. **Step 4**: Create `docs/src/hardware/bootstrap-runbook.md` and update `bootstrap.md`, `README.md`, and `SUMMARY.md`.
1. **Step 5**: Run `mdbook build docs` and verify clean build.

______________________________________________________________________

## Open Questions

None — all requirements, codebase facts, and target files have been audited and verified.
