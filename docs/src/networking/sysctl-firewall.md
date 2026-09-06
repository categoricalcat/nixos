# Sysctl And Firewall

This page records the current kernel and firewall posture. It is descriptive:
the Nix modules remain the source of truth.

## Shared Baseline

`modules/networking/sysctl-base.nix` is imported by `yifuwuqi`, `yirukou`,
and `yitaishi`.

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

- Enables IPv4 and IPv6 forwarding globally. RA reception is handled by
  systemd-networkd in userspace, so no `accept_ra` sysctl is needed; fallback
  WAN `enp6s0` disables RA and IPv6 link-local addressing in its `.network`
  unit instead.
- Loose reverse-path filtering is set on yirukou itself. Tailscale maps
  `routingMode = "both"` to `useRoutingFeatures = "server"`, which does not
  enable loose RPF. yifuwuqi inherits loose RPF from Tailscale client mode.
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
forward filtering enabled. Named nft sets (`wan_ifaces`, `internal_ifaces`,
`wan_bogon_v4`, `wan_bogon_v6`) are shared with `nixos-fw` via `mkBefore`.
Denies run in `yirukou-edge` (`raw` and `filter - 10`) before `nixos-fw`.
Port opens and LAN-to-WAN accepts stay in `networking.firewall`, which is
policy drop.

Internal interfaces:

- `br0`
- `enp2s0.42`
- `tailscale0`

WAN interfaces:

- `enp7s0`
- `enp6s0`

Allowed internal services on `br0` and `enp2s0.42`:

- TCP `53`, `80`, `443`, `853`, `3443`
- UDP `53`, `67`, `853`

Edge hardening:

- Invalid state is dropped by `nixos-fw` itself, in both the input and forward
  conntrack vmaps.
- IPv4 ICMP is allowed from internal interfaces. ICMPv6 is accepted by
  `nixos-fw` `input-allow` except redirects and node-info queries.
- WAN IPv4 ping is rate-limited to `5/second` by an accept in
  `networking.firewall`; WAN IPv6 ping is rate-limited by a drop in
  `yirukou-edge`, because `nixos-fw` accepts all ICMPv6 in `input-allow`.
- Raw prerouting drops spoofed/bogon IPv4 and IPv6 sources arriving on WAN,
  including `fe80::/10`, and all IPv6 arriving on fallback WAN `enp6s0`.
- Essential primary-WAN ICMPv6/ND and DHCPv6 replies are accepted in the
  `wan_ll_ok` jump chain before `wan_bogon`. Only RA, NS, NA, and the four
  ICMPv6 error types are exempted, and only on `enp7s0`.
- A pre-filter edge chain runs before the NixOS ICMPv6 accept rules. It drops
  unsolicited WAN-to-internal IPv6 and all IPv6 forwarding through fallback
  WAN `enp6s0`.
- NAT44 masquerades traffic from internal interfaces to WAN; NAT66 is absent.
- Plain DNS (TCP/UDP 53) from `br0`, VLAN 42, and `tailscale0` is redirected
  to local AdGuard Home unless the destination is already an AGH bind address,
  a local address, or Tailscale MagicDNS (`100.100.100.100` or
  `fd7a:115c:a1e0::53`). yifuwuqi Unbound iteration (`10.42.0.2` and IPv6 IID
  `::2` arriving on `br0`) is not redirected.
- Off-net DoT/DoQ (TCP/UDP 853) from those interfaces to WAN is dropped.
  DoH on 443 is not intercepted. AGH DDR advertises DoH on TCP 3443 (open on
  LAN/VLAN) and DoQ on 853.

Forwarding behavior:

- Internal IPv4 may forward to either WAN; internal IPv6 may forward only to
  primary WAN `enp7s0`.
- Established/related IPv6 replies, including ICMPv6 errors and PMTU messages,
  return through the `nixos-fw` forward conntrack vmap; unsolicited inbound
  IPv6 is dropped in `yirukou-edge`.
- Tailscale clients may reach the LAN subnet `10.42.0.0/24`. Established LAN
  replies return through the `nixos-fw` forward conntrack vmap.

That explicit Tailscale forwarding is what makes tailnet clients able to reach
LAN addresses through the advertised subnet, not only direct Tailscale IPs.

## yifuwuqi Firewall

`hosts/yifuwuqi/networking/firewall.nix` enforces default-deny on `eno1` and implements the principle of least privilege for container networking:

- Trusted interface: `tailscale0`.
- Allowed on `eno1` (LAN): SSH, AdGuard Home web UI, AdGuard Home DNS (`53`).
- Gateway traffic: `yirukou` reverse proxy and DNS resolver traffic allowed.
- Container least-privilege isolation:
  - DNS resolution: UDP/TCP `53` allowed from container subnets (`10.88.0.0/16`, `172.17.0.0/16`, `172.18.0.0/16`).
  - Scoped host API access: TCP `24686` (Lidarr for soularr) and TCP `24888` (SearXNG for firecrawl) allowed explicitly.
  - Default drop: All other host ports (SSH `24212`, Cockpit `24091`, PostgreSQL `5432`, Valkey `24379`, Prometheus `24090`, Samba `445`, Exporters) are dropped for container subnets.
- Forwarding isolation:
  - Containers are blocked from forwarding to private subnets (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`).

## Source Files

- `modules/networking/sysctl-base.nix`
- `hosts/yifuwuqi/networking/sysctl.nix`
- `hosts/yifuwuqi/networking/firewall.nix`
- `hosts/yirukou/networking/sysctl.nix`
- `hosts/yirukou/networking/firewall.nix`
- `modules/networking/sinkhole.nix`
