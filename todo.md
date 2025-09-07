## NixOS Improvement Checklist (live)

### Security

- [ ] consider SSH: set `PasswordAuthentication = no` once keys+2FA are confirmed; optionally add `Match` blocks to restrict by `AddressFamily`/`From`.
- [ ] Enable audit logs: `security.auditd.enable = true` and consider basic audit rules.

### Networking

- [ ] Bonding: relax `MIIMonitorSec` to ~1s and add modest `UpDelaySec`/`DownDelaySec` to reduce flapping.

### Reverse proxy / Nginx + Cloudflare

- [ ] Nginx: create reverse-proxy vhosts for `fufu.land` and `cockpit.fufu.land`.
- [ ] TLS: use Cloudflare Origin Certificate + key stored with `sops-nix`; set Cloudflare SSL mode to Full (strict); configure `ssl_certificate`/`ssl_certificate_key` in Nginx.
- [ ] Firewall: open TCP 80/443; keep HTTP → HTTPS redirect on 80.
- [ ] Cloudflare real IP: trust CF IP ranges (`real_ip_from`) and `real_ip_header CF-Connecting-IP`; forward proxy headers.
- [ ] Hardening: add security headers and proxy timeouts; optional gzip/brotli.
- [ ] Fail2ban: add nginx jail when exposing HTTP(S).
- [ ] Docs: record Cloudflare proxying mode and origin cert handling.

### Containers (Podman)

- [ ] Consider `podman-auto-update` with units/healthchecks for long-running services.
- [ ] Re-validate MTU 1492 end-to-end (bond0 ↔ WAN ↔ VPN/containers) and document rationale.
- [ ] Enable `virtualisation.podman.autoUpdate.enable = true;` and add healthchecks in units/compose for critical containers.
- [ ] Set `events_logger = "journald"` in `containers.conf` for complete journal integration.

### Performance and reliability

- [ ] Add `boot.loader.systemd-boot.configurationLimit = 10`.
- [ ] Add kernel safety nets: `kernel.panic = 10`, `kernel.panic_on_oops = 1`.
- [ ] Raise inotify limits for dev/containers: `fs.inotify.max_user_watches`/`max_user_instances`.
- [ ] Rate-limit journald bursts: `RateLimitIntervalSec=30s`, `RateLimitBurst=1000`.

### Documentation

- [ ] Add a short Architecture section (boot, networking, services, server-mode; how `serverMode.headless` gates features).

### System-specific

- [ ] Cockpit metrics: enable `services.pcp` and optionally `services.pmlogger`.
- [ ] Document or implement Minecraft server setup (port 25565 is open).
