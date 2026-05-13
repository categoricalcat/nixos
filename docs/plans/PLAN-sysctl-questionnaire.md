# Sysctl Questionnaire Decisions

This records the accepted sysctl and router-hardening choices for:

- `yifuwuqi`: general services server
- `yirukou`: public-facing router/gateway

Implementation should split shared baseline settings from host-specific deltas.

## Part A: yifuwuqi Cleanup

Accepted:

- Remove IPv4 and IPv6 forwarding from `hosts/yifuwuqi/networking/sysctl.nix`.
- Remove `net.ipv6.conf.all.disable_ipv6 = 0`.
- Remove `net.ipv6.conf.all.use_tempaddr = 0`.
- Remove `net.ipv6.conf.all.accept_ra = 1`.
- Remove `net.ipv4.conf.all.src_valid_mark = 1`.
- Remove `services.fstrim.enable = true` from the sysctl file.
- Remove strict `rp_filter` sysctl overrides and let `networking.firewall.checkReversePath = "loose"` work as intended for Tailscale exit-node traffic.

Rationale: `yifuwuqi` is now a services host, not the router. Tailscale exit-node use requires loose reverse-path behavior, and several current lines are defaults or already owned by other NixOS modules.

## Part B: Shared Baseline

Accepted:

- Create a shared baseline module, probably `modules/networking/sysctl-base.nix`.
- Keep baseline hardening:
  - `net.ipv4.tcp_syncookies = 1`
  - `net.ipv4.tcp_rfc1337 = 1`
  - disable redirects
  - disable source routes
  - ignore ICMP broadcasts
  - ignore bogus ICMP errors
- Use per-host queue disciplines:
  - `yifuwuqi`: `fq`
  - `yirukou`: `fq_codel`
- Keep `vm.vfs_cache_pressure = 50` as shared baseline.

Rationale: these are general low-risk hardening and behavior defaults, while the qdisc should reflect host role.

## Part C: yifuwuqi Server Settings

Accepted:

- Keep BBR on `yifuwuqi`.
- Load `tcp_bbr`.
- Drop `tcp_htcp` fallback unless a future config explicitly needs it.
- Reduce socket max buffers from `256 MiB` to `64 MiB`.
- Keep `tcp_rmem` and `tcp_wmem` middle value at `262144`.
- Keep server backlog tunings:
  - `net.core.somaxconn = 4096`
  - `net.ipv4.tcp_max_syn_backlog = 8192`
  - `net.core.netdev_max_backlog = 10000`
  - `net.core.netdev_budget = 1200`
- Keep TCP keepalive at `300 / 3 / 30`.
- Keep `net.ipv4.tcp_mtu_probing = 2`.
- Keep `net.ipv4.tcp_notsent_lowat = 16384`.
- Keep zram on `yifuwuqi` at `zramSwap.memoryPercent = 100`.
- Set `vm.swappiness = 100` on `yifuwuqi`.

Rationale: `yifuwuqi` is a TCP endpoint with nginx/services/AI workloads and zram configured as high-priority compressed swap.

## Part D0: yirukou WAN Ingress

Accepted:

- Add bogon/source-spoof filters on WAN.
- Use default-drop WAN input.
- Allow only explicit WAN services.
- Use Cloudflare Tunnel as outbound-only by default, so no inbound `80` or `443` is required for public web services.
- Allow Tailscale UDP from public non-bogon sources.
- Treat `playit-agent` as outbound-only, so no WAN allow rule is required unless a future non-agent mode needs one.
- Do not expose public DNS on WAN by default.
- Allow rate-limited ICMP for diagnostics.

Rationale: yirukou may face a public static IP. Public service exposure should prefer outbound tunnels and explicit allow rules.

## Part D: yirukou Router Settings

Accepted:

- Move IPv4 forwarding into `hosts/yirukou/networking/sysctl.nix`.
- Wait on IPv6 forwarding until routed IPv6 / prefix delegation is designed.
- Use `rp_filter = loose` initially for compatibility with Tailscale, failover, and PBR.
- Do not rely on `rp_filter` as the main router security boundary.
- Harden WAN with nftables:
  - default-drop input and forward
  - accept `ct state established,related`
  - drop invalid state
  - explicit WAN ingress allow-list
  - interface/source-prefix anti-spoofing
- Add fwmark/PBR foundations for WAN failover and future VPN egress.
- Restore packet marks from `ct mark` early.
- Save packet marks back to `ct mark` for flow consistency.
- Use separate routing tables for primary WAN, fallback WAN, and optional VPN.
- Allow switching specific interfaces from `rp_filter = 2` to `0` only if valid marked asymmetric traffic is dropped.
- Set `nf_conntrack_max = 262144`.
- Set `nf_conntrack_tcp_timeout_established = 7440`.
- Adopt shorter conntrack timeouts:
  - `generic = 120`
  - `udp = 30`
  - `udp_stream = 180`
  - `tcp_close_wait = 60`
  - `tcp_fin_wait = 120`
  - `tcp_time_wait = 120`
- Set `nf_conntrack_helper = 0`.
- Use `net.core.default_qdisc = "fq_codel"`.
- Use router-sized buffers:
  - `rmem_max = 16 MiB`
  - `wmem_max = 16 MiB`
  - `netdev_max_backlog = 5000`
  - `netdev_budget = 600`
- Do not copy yifuwuqi's BBR/keepalive endpoint tuning to yirukou.
- Add ICMP rate limiting.
- Disable source routes and secure redirects.
- Keep kernel-hardening sysctls for future `serverMode.appliance`, not the sysctl host file.
- Disable zram on `yirukou`.
- Since yirukou has physical swap, use low swap tendency such as `vm.swappiness = 10`.
- Set `vm.min_free_kbytes = 65536`.
- Set policy-routing helper knobs:
  - `net.ipv4.tcp_fwmark_accept = 1`
  - `net.ipv4.fib_multipath_use_neigh = 1`

Rationale: yirukou is a router, not a service endpoint. Its safety should come from nftables, conntrack, PBR, explicit ingress policy, and bogon filtering.

## Part E: File Layout

Accepted:

- Create `modules/networking/sysctl-base.nix`.
- Keep per-host files:
  - `hosts/yifuwuqi/networking/sysctl.nix`
  - `hosts/yirukou/networking/sysctl.nix`
- Move BBR module loading into yifuwuqi-only config.
- Drop `tcp_htcp` fallback.
- Import the shared baseline from both host networking configs.
- Keep yirukou firewall, bogon filtering, conntrack marks, and PBR work in `hosts/yirukou/networking/firewall.nix` or adjacent router-specific networking modules, not in the sysctl module.

## Implementation Notes

The implementation should preserve these boundaries:

- `modules/networking/sysctl-base.nix`: shared host hardening.
- `hosts/yifuwuqi/networking/sysctl.nix`: endpoint/server TCP tuning.
- `hosts/yirukou/networking/sysctl.nix`: router kernel and conntrack tuning.
- `hosts/yirukou/networking/firewall.nix`: nftables filtering, bogon rules, conntrack state policy, NAT, marks, and PBR hooks.

The current yirukou firewall opens `80`, `443`, and `853` on WAN. That should be replaced with the accepted WAN ingress posture unless direct public services are explicitly needed later.
