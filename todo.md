## NixOS Improvement Checklist (live)

### Quick wins

- [ ] Secure Cockpit with TLS via `security.acme` and/or reverse proxy in `services.nginx`; set `AllowUnencrypted = false`; restrict `allowed-origins`.
- [ ] SSH: set `PasswordAuthentication = no` once keys+2FA are confirmed; optionally add `Match` blocks to restrict by `AddressFamily`/`From`.
- [x] README: fix path to `/etc/nixos` and add brief usage notes for flake builds.
- [ ] Remove `docker` group from users; keep `podman` only.
- [x] WSL: deduplicate `nixowos.nixosModules.default` import.

### Security

- [ ] Integrate `sops-nix` or `agenix` for secrets (WireGuard keys, future tokens).
- [ ] Fail2ban: add nginx/cockpit jails if exposing HTTP(S); tune bans.
- [ ] SSH: keep 2FA, `MaxAuthTries = 3`, `LoginGraceTime = 30s` (already present/close; re-validate values).

### Networking

- [ ] Decide DNS strategy: enable `services.resolved` or go dnsmasq-only; avoid hand-managed `resolv.conf` unless required; document container/VPN DNS.
- [x] Import `modules/services/dnsmasq.nix` for VPN-scoped DNS on `wg0`.
- [ ] WireGuard: consider an IPv6 ULA prefix for clients and Router Advertisements; validate firewall for IPv6.
- [ ] Bonding: relax `MIIMonitorSec` to ~1s and add modest `UpDelaySec`/`DownDelaySec` to reduce flapping.

### Containers (Podman)

- [ ] Switch container log driver to `journald` for central logging.
- [ ] Consider `podman-auto-update` with units/healthchecks for long-running services.
- [ ] Re-validate MTU 1492 end-to-end (bond0 ↔ WAN ↔ VPN/containers) and document rationale.

### Performance and reliability

- [ ] ZRAM: tune `zramSwap.memoryPercent` to 25–50 unless workloads need more.
- [ ] Remove `discard` from `/` mount options; rely on weekly `fstrim`.
- [ ] Review aggressive TCP buffer/sysctl sizing; document rationale per setting.
- [ ] Add `boot.loader.systemd-boot.configurationLimit = 10`.

### GPU / Compute (ROCm)

- [ ] Gate graphics/GUI bits when `serverMode.headless = true`; keep only compute essentials (ROCm, OpenCL) for Ollama.
- [x] Keep `/opt/rocm` tmpfiles symlink for consumers (Ollama) – already present.

### Nix / Flakes / DevEx

- [ ] Add pre-commit with `statix`, `deadnix`, and one formatter (`nixfmt-rfc-style` or `alejandra`) via `treefmt-nix`.
- [ ] CI: run `nix flake check`, build `.#nixosConfigurations.{fufuwuqi,wsl}`, and lint (`statix`, `deadnix`).
- [ ] DevShell with `nil` (Nix LSP), lint tools, and `pre-commit`.
- [ ] Optional: deploy tooling (`deploy-rs` or `colmena`).

### Documentation

- [ ] Add a short Architecture section (boot, networking, services, server-mode; how `serverMode.headless` gates features).
- [ ] Keep a minimal `CHANGES.md` for operational changes (ports, exposure, services).

### Cleanup and consistency

- [ ] Remove duplicate `programs.mtr.enable` (present in both `users/users.nix` and `modules/services/services.nix`).
- [ ] Clarify/remove unused overlay `androidndkPkgs_23b`.

### System-specific

- [ ] Enable `security.tpm2` and `services.fwupd` for firmware updates.
- [ ] Ensure `hardware.enableRedistributableFirmware = true;` so AMD microcode updates apply.
- [ ] Optionally consider `pkgs.linuxPackages_lts` for stability; pin latest only if needed for AMDGPU.
- [ ] Cockpit metrics: enable `services.pcp` and optionally `services.pmlogger`.

Note: Items with [x] are already implemented in this repo; others are recommended next steps.