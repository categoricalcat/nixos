# Sysctl And Firewall

This page records the current kernel and firewall posture. It is descriptive:
the Nix modules remain the source of truth.

## Shared Baseline

`modules/networking/sysctl-base.nix` is imported by both `yifuwuqi` and
`yirukou`.

It sets low-risk host hardening defaults:

- TCP syncookies enabled.
- RFC 1337 TIME-WAIT protection enabled.
- IPv4 and IPv6 ICMP redirects disabled.
- IPv4 secure redirects and sent redirects disabled.
- IPv4 and IPv6 source routing disabled.
- Broadcast pings and bogus ICMP errors ignored.
- `vm.vfs_cache_pressure = 50`.

## yifuwuqi Server Tuning

`hosts/yifuwuqi/networking/sysctl.nix` treats `yifuwuqi` as a service endpoint,
not as the LAN router.

Current behavior:

- Uses BBR congestion control with `tcp_bbr` loaded.
- Uses `fq` as the default queue discipline for paced TCP flows.
- Allows 64 MiB receive and send socket buffers.
- Increases backlog and SYN backlog for service bursts.
- Keeps TCP keepalive at `300 / 3 / 30`.
- Enables aggressive PMTU probing with `net.ipv4.tcp_mtu_probing = 2`.
- Uses `vm.swappiness = 100` because zram is preferred for service and AI
  workloads.

## yirukou Router Tuning

`hosts/yirukou/networking/sysctl.nix` treats `yirukou` as a public-facing
router.

Current behavior:

- Enables IPv4 forwarding globally.
- Leaves IPv6 forwarding undesigned for now.
- Uses loose reverse-path filtering for Tailscale, WAN failover, and future
  policy routing compatibility.
- Uses `fq_codel` to reduce router egress bufferbloat.
- Keeps router socket buffers at 16 MiB maximum.
- Sizes packet backlog and poll budget for forwarding.
- Raises conntrack capacity to `262144`.
- Disables automatic conntrack helpers.
- Shortens generic, UDP, established TCP, and TCP teardown conntrack timeouts.
- Enables `net.ipv4.tcp_fwmark_accept` and
  `net.ipv4.fib_multipath_use_neigh` as policy-routing foundations.
- Uses low swap tendency with `vm.swappiness = 10`.
- Keeps a 64 MiB free-memory reserve through `vm.min_free_kbytes = 65536`.

## yirukou Firewall

`hosts/yirukou/networking/firewall.nix` uses the NixOS nftables backend with
forward filtering enabled.

Internal interfaces:

- `br0`
- `enp2s0.42`
- `tailscale0`

WAN interfaces:

- `enp7s0`
- `enp6s0`

Allowed internal services on `br0` and `enp2s0.42`:

- TCP `53`, `80`, `443`, `853`
- UDP `53`, `67`, `853`

Edge hardening:

- Invalid WAN input and forward state is dropped.
- ICMP and ICMPv6 are allowed from internal interfaces.
- WAN ping is rate-limited to `5/second`.
- Raw prerouting drops spoofed/bogon IPv4 and IPv6 sources arriving on WAN.
- NAT masquerades traffic from internal interfaces to WAN.

Forwarding behavior:

- Internal interfaces may forward to WAN.
- Tailscale clients may reach the LAN subnet `10.42.0.0/24`.
- Established LAN replies back to Tailscale subnet clients are allowed.

That explicit Tailscale forwarding is what makes tailnet clients able to reach
LAN addresses through the advertised subnet, not only direct Tailscale IPs.

## Source Files

- `modules/networking/sysctl-base.nix`
- `hosts/yifuwuqi/networking/sysctl.nix`
- `hosts/yirukou/networking/sysctl.nix`
- `hosts/yirukou/networking/firewall.nix`
- `modules/networking/sinkhole.nix`
