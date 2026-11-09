# VPN to LAN Migration Plan

## Status: DRAFT — Phases 1–2 deployed and verified; Phase 1 on 2026-11-08, Phase 2 on 2026-11-09

## Objective

Migrate internal service access controls, firewall rules, and reverse proxy definitions away from overlay network bindings (Tailscale `100.64.0.0/10` and `100.69.0.x`, NetBird `100.42.0.0/16`) to the trusted local LAN (`10.42.0.0/24` and `fd75:c55f:6d19:1::/64`).

Under this architecture:

- Source-address allowlists in services that remain LAN-reachable name only LAN
  CIDRs and loopback, never overlay CIDRs. Allowlists narrow reachability;
  authentication belongs to the
  [Service Security Architecture Plan](service-security-architecture-plan.md).
- Remote access to client-facing and explicitly allowed LAN services is
  consolidated through `yirukou`'s Tailscale subnet router (`10.42.0.0/24`
  with SNAT), so remote connections arrive at backend services and at
  `yirukou`'s nginx as gateway LAN traffic (`10.42.0.1`). Internal
  administration uses SSH on `yifuwuqi`.
- Servers stop trusting `tailscale0` wholesale. Direct ingress from the VPN overlay to unproxied backend services is eliminated.

```mermaid
flowchart TD
    subgraph External["Remote / Roaming Clients"]
        REMOTE["Roaming Node (100.64.0.0/10)"]
    end

    subgraph Gateway["Host: yirukou (Gateway & Subnet Router)"]
        SR["Tailscale Subnet Router<br/>(10.42.0.0/24 with SNAT 10.42.0.1)"]
        NGX["Nginx Reverse Proxy<br/>(trustedProxyCidrs LAN)"]
    end

    subgraph LAN["Trusted LAN (10.42.0.0/24)"]
        subgraph Yifuwuqi["Host: yifuwuqi (Core Server Daemons)"]
            direction TB
            SMB["Samba Server<br/>(hosts allow LAN)"]
            APPS["Client-facing hosted services<br/>(allowlists and origins LAN)"]
            ADMIN["Administrative services<br/>(SSH on yifuwuqi)"]
            PG["PostgreSQL<br/>(auth per service-security plan)"]
        end
    end

    REMOTE -->|Tailscale Tunnel| SR
    REMOTE -->|"Tailscale Tunnel, input SNAT 10.42.0.1"| NGX
    SR -->|SNAT gateway traffic 10.42.0.1| SMB
    SR -->|SNAT gateway traffic 10.42.0.1| PG
    NGX -->|proxy from 10.42.0.1| APPS
```

### Scope

Owns:

- Subnet routing, the `yirukou` subnet router, and its `yirukou-nat` input
  SNAT that presents subnet-route clients to nginx as `10.42.0.1`.
- `tailscale0` firewall trust on servers (`modules/services/tailscale.nix` and per-host tailnet ports).
- Overlay CIDRs and addresses in allowlists: nginx `trustedProxyCidrs` and the legacy VPN vhost, Samba `hosts allow`, Cockpit `allowed-origins`, and the Forgejo webhook `ALLOWED_HOST_LIST`.
- NetBird leftovers in `modules/addresses.nix` (`network.netbird`, sshd `listenAddresses`, AdGuard `dnsBindHosts`).

Not owned here:

- Postgres authentication and listen addresses, the qBittorrent whitelist, the `yifuwuqi` gateway rule and container isolation: [Service Security Architecture Plan](service-security-architecture-plan.md).
- Cryptographic identity of the proxy hop: [mTLS Architecture Plan](mtls-architecture-plan.md).
- Persisting Tailscale state on `yirukou`: [Impermanence on yirukou](impermanence-yirukou-plan.md).

______________________________________________________________________

## Evidence Status

- **Repository-verified**: Phase 1's active Samba ACL excludes the VPN CIDR.
  Phase 2's source removes the overlay entries from nginx, Forgejo, and
  Cockpit, deletes the legacy vhost and OpenVSCode module, adds the
  `yirukou-nat` input SNAT, and maps `ssh.fufu.land` to `yifuwuqi`'s LAN SSH.
  Unconditional `tailscale0`
  trust and NetBird remnants for later phases remain in the Nix configuration.
- **Live-host verified 2026-11-08**: `yifuwuqi` prefers its default route via
  `10.42.0.1`; this does not prove Tailnet route approval or client adoption.
- **Preflight verified 2026-11-08**: `yitaishi` installs
  `10.42.0.0/24` through `tailscale0` and reaches `10.42.0.2`.
- **Phase 1 verified 2026-11-08**: yitaishi's enabled automount targets
  `//10.42.0.2/share`; Samba answers on `10.42.0.2:445` with the LAN-only
  allowlist.
- **Phase 2 preflight 2026-11-08**: `yitaishi` holds no `10.42.0.0/24`
  address and routes that subnet only through `tailscale0`, whose sole address
  is `100.69.0.4`. `yirukou` runs kernel-mode Tailscale (`tailscale0` holds
  `100.69.0.1`). Its masquerade covers only forwarded traffic, so connections
  to `10.42.0.1` itself keep the client's tailnet source.
- **Operational verification pending**: Tailscale SSH behavior after the later
  trust change.

______________________________________________________________________

## Current State

1. **Reverse Proxy & Web Access** (Phase 2, deployed 2026-11-09):

   - In `modules/services/nginx-proxy.nix`, `trustedProxyCidrs` names only
     `yirukou`'s trusted LAN IPv4/IPv6 CIDRs and omits the untrusted VLAN
     CIDRs (`10.42.42.0/24` and `fd75:c55f:6d19:2::/64`). The legacy test
     virtual host for the VPN address is gone.
   - The `yirukou-nat` input chain in `hosts/yirukou/networking/firewall.nix`
     SNATs `tailscale0` connections to `10.42.0.1` on nginx's HTTP and HTTPS
     ports to `10.42.0.1`. Direct connections to `100.69.0.1` keep their
     tailnet source, and nginx denies them.
   - In `modules/services/forgejo.nix`, the webhook `trustedCidrs` name only
     the LAN CIDR. Forgejo classifies `100.64.0.0/10` as `private`, so its
     `external` builtin does not admit tailnet webhook targets.
   - In `modules/services/cockpit.nix`, `allowed-origins` names no overlay
     address.

1. **Storage and Database**:

   - In `modules/services/postgresql.nix`, `pg_hba.conf` grants passwordless `trust` to the entire VPN CIDR: `host all all ${allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr} trust`. The service-security plan (Decision 5) removes it along with every other `trust` entry.
   - The active `modules/services/samba/server.nix` allows only `${lanCidr}`,
     `${lanCidr6}`, and loopback.
   - In `modules/services/samba/client.nix`, CIFS mounts are **already migrated**: `serverIp` is set to `yifuwuqi.network.lan.ipv4.host` (`10.42.0.2`), with no VPN daemon dependencies.

1. **Firewall & Container Isolation**:

   - Service Security Phase 0's staged forward policy removes
     `trustedHostDestinations` entirely. VPN Phase 3 no longer has a separate
     source edit for that former VPN entry.
   - `modules/services/tailscale.nix` adds `tailscale0` to `networking.firewall.trustedInterfaces` on every host that imports it. Tailnet peers reach every listening port on `yifuwuqi` (including Postgres) and `yirukou` directly. On `yirukou` this makes the SSH-only `tailscale0` rule in `hosts/yirukou/networking/firewall.nix` dead config, and `yifuwuqi` lists `tailscale0` a second time in its own firewall file.

1. **NetBird Leftovers**:

   - The NetBird module is commented out on every host, but `modules/addresses.nix` still defines `network.netbird` for each one.
   - sshd `listenAddresses` and `yifuwuqi`'s AdGuard `dnsBindHosts` include the NetBird address. With `ip_nonlocal_bind = 1` (`modules/networking/sysctl-base.nix`), sshd and AdGuard listen on `100.42.0.2` although no interface carries it.
   - qBittorrent's `AuthSubnetWhitelist` names `100.42.0.0/16`, which is public address space, not CGNAT.
   - `modules/services/netbird.nix` marks `wt0` trusted, so re-enabling NetBird would reopen every port on that interface.

1. **Peerings & Roaming Nodes (Intentional Tailscale Usage)**:

   - `yirukou` declares the `10.42.0.0/24` advertised subnet route. Separately,
     `yifuwuqi` declares its `192.168.0.1/32` route; these are distinct
     routing responsibilities and must not be conflated as one ingress path.
   - **`lan-mouse`**: As documented in `docs/src/hardware/lan-mouse.md`, KVM traffic between `yitaishi` and `yixiaoqing` is bound to Tailscale (`100.x.x.x`). This is required because `yixiaoqing` is a laptop with no static LAN reservation that frequently roams across networks, and `yitaishi` does not have a static LAN IP assigned in `modules/addresses.nix`.
   - **Distributed Builds**: `modules/distributed-builds.nix` targets `yitaishi` via its VPN address because `yitaishi`'s sshd binds strictly to VPN interfaces and `hosts.yitaishi` does not possess a static `network.lan` block in `addresses.nix`.
   - **Obsolete Components**: `llama-swap-amdgpu` (port 50052) was completely removed from the gang and replaced by local `llama-cpp-node`. Phase 2 deletes the unimported `modules/services/openvscode-server.nix`, which `modules/services/opencode.nix` replaced.

______________________________________________________________________

## Decisions

### 1. Subnet Router as the Single Remote Ingress Boundary

- `yirukou` declares `10.42.0.0/24` to Tailscale with default SNAT masquerade
  enabled. Route approval and a client reaching the LAN through it are
  admission gates before removing overlay allowlists.
- Remote devices access client-facing services and Samba through their LAN IP
  addresses (`10.42.0.1`, `10.42.0.2`) over the subnet route. PostgreSQL stays
  loopback-only under the service-security plan.
- Remove `100.64.0.0/10` from service allowlists. Tailscale's default SNAT
  covers only traffic `yirukou` forwards, such as connections to `10.42.0.2`.
  Connections that end on `10.42.0.1` itself are delivered locally with the
  client's tailnet source, so the `yirukou-nat` input chain SNATs
  `tailscale0` connections to `10.42.0.1` on nginx's HTTP and HTTPS ports to
  `10.42.0.1`. Remote traffic then matches LAN allowlists on both hosts.
  Direct connections to `yirukou`'s tailnet address `100.69.0.1` are not
  translated, and nginx denies them.
- SNAT consequence: on `yifuwuqi`, every remote client is indistinguishable from `yirukou` itself. Rules keyed on `10.42.0.1` apply to all remote clients; the service-security plan scopes them (its Decision 3), and the mTLS plan's Tier 2 gives the proxy hop a cryptographic identity.
- On `yirukou`, nginx, GoAccess, and AdGuard DoH logs likewise record
  `10.42.0.1` for subnet-route clients. Tailnet policy remains the per-device
  gate (Decision 7).
- `ssh.fufu.land` is plain SSH to `yifuwuqi`: AdGuard rewrites it to
  `10.42.0.2`, and the generated client block targets `10.42.0.2:24212` with
  `yifuwuqi`'s pinned host key, so it works on the LAN and over the subnet
  route. The Cloudflare SSH fail-safe is published as `cloudflare.fufu.land`.
  Subnet-route clients arrive SNAT'd as `10.42.0.1`, so sshd's password
  exception excludes that address (`Match Address 10.42.0.0/24,!10.42.0.1`):
  they are key-only, and neither fail2ban's sshd jail nor sshd's
  `PerSourcePenalties` throttles the shared address.

### 2. Restrict Reverse Proxy Access to LAN Subnets

- Client-facing hosted vhosts allow only `10.42.0.0/24` and
  `fd75:c55f:6d19:1::/64` for direct LAN access. Do not add the untrusted VLAN
  `10.42.42.0/24` or `fd75:c55f:6d19:2::/64`; administrative vhosts are
  SSH-only under the service-security plan.
- Remove `allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr` from `trustedProxyCidrs` in `modules/services/nginx-proxy.nix`.
- Delete the legacy `addresses.network.vpn.ipv4.host` virtual host block.
- Tailnet clients reach these vhosts only through the subnet route, as
  SNAT'd `10.42.0.1` traffic (Decision 1); no overlay CIDR returns to the
  allowlist.

### 3. PostgreSQL Follows the Service-Security Plan

- Postgres listen addresses and `pg_hba` belong to the [Service Security Architecture Plan](service-security-architecture-plan.md) (Decision 5). It removes the VPN CIDR line along with every other `trust` entry, instead of widening `trust` to `10.42.0.0/24`.
- This plan only requires that no Postgres rule names an overlay CIDR.

### 4. Restrict Samba Access to LAN

- Remove `vpnCidr` from `modules/services/samba/server.nix`, restricting `hosts allow` to `${lanCidr} ${lanCidr6} 127.0.0.1 localhost ::1`.

### 5. Clean Up Dead & Legacy Modules

- Remove `addresses.network.vpn.ipv4.host` from `modules/services/cockpit.nix` `allowed-origins`.
- Remove `allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr` from `modules/services/forgejo.nix` webhook allowlist.
- Service Security Phase 0 removes the former VPN entry with the entire
  `trustedHostDestinations` allow rule.
- Delete unimported legacy module `modules/services/openvscode-server.nix`.
- NetBird is retired: remove its addresses from sshd `listenAddresses` and
  AdGuard `dnsBindHosts`, then delete `modules/services/netbird.nix` and the
  `network.netbird` blocks. The qBittorrent whitelist entry goes with the
  service-security plan's Decision 5.

### 6. Preserve Tailscale for Dynamic and Roaming Peerings

- Retain Tailscale IPs for `lan-mouse` and `modules/distributed-builds.nix` until/unless dynamic nodes (`yitaishi`, `yixiaoqing`) receive static LAN allocations and static LAN listeners.

### 7. Servers Stop Trusting `tailscale0`

- **Current state**: `modules/services/tailscale.nix` adds `tailscale0` to
  `trustedInterfaces` in every routing mode, and `yifuwuqi` duplicates that
  trust in its host firewall.
- **Target state**: add `tailscale0` to `trustedInterfaces` only in `client`
  routing mode; server and router hosts declare explicit ports instead.
  Remove the duplicate entry in `hosts/yifuwuqi/networking/firewall.nix`.
- `yirukou`: `tailscale0` gets the same ports as `br0` (`lanTcpPorts` plus SSH, and `internalUdpPorts`), because tailnet clients use its DNS and nginx. Forwarding into `10.42.0.0/24` already has its own rule.
- `yifuwuqi`: `tailscale0` allows SSH `24212` and DNS `53` (AdGuard binds `100.69.0.6`).
- Clients (`yitaishi`, `yixiaoqing`) keep trusting `tailscale0`; `lan-mouse` and distributed builds depend on it (Decision 6).
- `yifuwuqi`'s Tailscale route to `192.168.0.1/32` keeps working: the service-security plan's Phase 0 adds its forward accept when it enables forward filtering.
- Host firewalls are the authoritative service boundary. Tailnet policy needs to
  permit authorized clients to use the subnet route, but it is not a second
  per-service authorization system in this plan.

______________________________________________________________________

## Phases

### Phase 1: Storage and Database Services — Deployed and Verified

1. PostgreSQL: no change in this plan; the service-security plan's Phase 2 replaces `pg_hba`.
1. `modules/services/samba/server.nix` removes `vpnCidr` from `hosts allow`.
   The subnet route, automount target, and Samba listener were verified after
   deployment.

### Phase 2: Web, Proxy, and Development Services — Deployed and Verified

Status: deployed 2026-11-09. Verified from `yifuwuqi` and `yitaishi`:
`docs.fufu.land` returned 200 over trusted LAN IPv4 and over the Tailnet
subnet route (the 200 proves the `yirukou-nat` input SNAT, since an
untranslated tailnet source would draw 403), direct `100.69.0.1` requests
returned 403, and `ssh.fufu.land` resolves to `10.42.0.2` with sshd
answering. Untrusted-VLAN runtime rejection and the Cloudflare dashboard
hostname move to `cloudflare.fufu.land` remain operator-side checks; trusted
LAN IPv6 is config-level only because AdGuard publishes no AAAA rewrite.

1. In `modules/services/nginx-proxy.nix`, remove `yifuwuqi.network.vpn.ipv4.cidr` from `trustedProxyCidrs` and delete the `"${addresses.network.vpn.ipv4.host}"` virtual host.
1. In `hosts/yirukou/networking/firewall.nix`, add the `yirukou-nat` input
   chain that SNATs `tailscale0` connections to `10.42.0.1` on nginx's ports
   to `10.42.0.1`. It ships in the same `yirukou` generation as the allowlist
   change, so subnet-route clients never lose access.
1. In `modules/services/forgejo.nix`, remove `yifuwuqi.network.vpn.ipv4.cidr` from `trustedCidrs`.
1. In `modules/services/cockpit.nix`, remove VPN URLs from `allowed-origins`.
1. Delete unimported file `modules/services/openvscode-server.nix`.
1. Map `ssh.fufu.land` to `yifuwuqi`'s LAN SSH through `ssh.domain` in
   `modules/addresses.nix`, consumed by the AdGuard rewrite, the generated
   client block in `modules/services/ssh/dynamic.nix`, and the pinned names in
   `modules/services/ssh/known-hosts.nix`. Rename the Cloudflare client blocks
   in `users/assets/dotfiles/ssh/config` to `cloudflare.fufu.land`, pinned
   with `HostKeyAlias yifuwuqi`. Clients pick this up when their own
   generation deploys; the tunnel's public hostname moves in the Cloudflare
   dashboard.
1. Verify that `docs.fufu.land`, the designated client-facing probe vhost,
   accepts trusted LAN IPv4/IPv6 and subnet-route Tailnet traffic, returns
   403 to direct `100.69.0.1` requests, and rejects both IPv4 and IPv6
   untrusted-VLAN traffic. Verify `ssh ssh.fufu.land` from the LAN and from a
   subnet-route Tailnet client.

### Phase 3: Host Firewall Rules

1. The former `trustedHostDestinations` VPN entry was removed with Service
   Security Phase 0; no additional source edit remains for it here.
1. Apply Decision 7 in `modules/services/tailscale.nix`, `hosts/yirukou/networking/firewall.nix` and `hosts/yifuwuqi/networking/firewall.nix` only after Service Security Phase 0 has accepted `tailscale0 -> enp4s0` traffic to `192.168.0.1/32`.
1. Apply the NetBird retirement cleanup from Decision 5 in
   `modules/addresses.nix` and `modules/services/netbird.nix`.

### Phase 4: Validation & Evaluation

1. Run `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run` across `yifuwuqi` and `yirukou`.
1. Verify that services build and evaluate cleanly without syntax errors or broken references.
1. Check that `nix eval .#nixosConfigurations.<host>.config.networking.firewall.trustedInterfaces` no longer lists `tailscale0` on `yifuwuqi` and `yirukou`.

______________________________________________________________________

## Rollout Order

```mermaid
flowchart LR
    P1["Phase 1: Samba allowlist"]
    P2["Phase 2: Web and development services"]
    P3["Phase 3: Tailnet firewall and NetBird cleanup"]
    P4["Phase 4: Validation & Deploy"]
    SEC0["Service Security Phase 0"]

    P1 --> P2 --> P3 --> P4
    SEC0 --> P3
```

Fleet sequencing is defined by the [Architecture Security Rollout](architecture-rollout-plan.md).
Deploy and validate each phase independently:

1. **Admission gate**: verify an approved `yirukou` subnet route and a Tailnet
   client reaching LAN services through it.
1. **Phase 1**: remove Samba's VPN allowlist, then verify Samba through the
   subnet route.
1. **Phase 2**: remove the proxy, Forgejo, Cockpit, and legacy vhost overlay
   entries and add the `yirukou` input SNAT in one `yirukou` generation;
   delete the unimported OpenVSCode module; map `ssh.fufu.land` to
   `yifuwuqi`'s LAN SSH and move the Cloudflare fail-safe to
   `cloudflare.fufu.land`; verify trusted-LAN and subnet-route Tailnet access
   succeed while direct-overlay and untrusted-VLAN access fail.
1. **Phase 3**: after Service Security Phase 0 passes, apply Decision 7 and
   perform the NetBird retirement cleanup.
1. **Phase 4**: evaluate both hosts, deploy the completed phase through
   [CI/CD](../services/ci-cd.md) section 5, and verify from a Tailnet client:
   - a designated client-facing hosted domain works over the subnet route;
   - `nc -zv 100.69.0.6 24200` fails (no direct overlay ingress to `yifuwuqi` backends);
   - Tailscale SSH and plain SSH on `24212` still work on both servers;
   - `tailscale status` still shows `yirukou`'s `10.42.0.0/24` route.

### Cross-Plan Dependencies

- **Fleet sequence**: [Architecture Security Rollout](architecture-rollout-plan.md)
  is the canonical dependency order.
- **Coordinates with** the [Service Security Architecture Plan](service-security-architecture-plan.md): it owns Postgres (Decision 3 here defers to it) and the qBittorrent whitelist; its gateway rule decides what SNAT'd remote clients reach on `yifuwuqi`; its staged Phase 0 removes the former container VPN allow rule and keeps the `192.168.0.1/32` tailnet route when forward filtering activates.
- **Unblocks** the [mTLS Architecture Plan](mtls-architecture-plan.md): Phase 2
  removes overlay access from `restrictedProxyConfig` for client-facing
  vhosts. Its Tier 2 remains LAN mTLS rather than a direct Tailscale
  transport.
- **Coordinates with** [Impermanence on yirukou](impermanence-yirukou-plan.md):
  the current Ext4 root already persists Tailscale state. If impermanence is
  deployed, `/var/lib/tailscale` must be persisted before rebooting into its
  tmpfs-root generation.

______________________________________________________________________

## Open Questions

1. **Tailscale SSH**: confirm it keeps working with `tailscale0` untrusted on one server before rolling out to both.
