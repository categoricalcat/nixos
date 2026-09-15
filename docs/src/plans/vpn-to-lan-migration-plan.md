# VPN to LAN Migration Plan

## Objective

Migrate internal service access controls, firewall rules, and reverse proxy definitions away from legacy VPN/Tailscale IP bindings (`100.64.0.0/10` and `100.69.0.x`) to the trusted local LAN (`10.42.0.0/24` and `fd75:c55f:6d19:1::/64`).

Under this architecture:

- Core server daemons (PostgreSQL, Samba, Forgejo, Nginx, Cockpit) trust only local LAN CIDRs and loopback.
- Remote access to internal services is consolidated through `yirukou`'s Tailscale subnet router (`10.42.0.0/24` with SNAT), causing remote connections to arrive at backend services as trusted gateway LAN traffic (`10.42.0.1`).
- Direct ingress access from the VPN overlay to unproxied backend services is eliminated.

______________________________________________________________________

## Current State

1. **Reverse Proxy & Web Access**:

   - In \[`modules/services/nginx-proxy.nix`\](file:///home/yi/the.files/nixos/modules/services/nginx-proxy.nix), `trustedProxyCidrs` includes `allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr` (`100.64.0.0/10`).
   - `nginx-proxy.nix` retains a legacy test virtual host binding directly to `"${addresses.network.vpn.ipv4.host}"`.
   - In \[`modules/services/forgejo.nix`\](file:///home/yi/the.files/nixos/modules/services/forgejo.nix), `trustedCidrs` includes the VPN CIDR for webhook delivery allowlists.
   - In \[`modules/services/cockpit.nix`\](file:///home/yi/the.files/nixos/modules/services/cockpit.nix), `allowed-origins` includes `http://${addresses.network.vpn.ipv4.host}:${port}` and `https://${addresses.network.vpn.ipv4.host}:${port}`.

1. **Storage and Database**:

   - In \[`modules/services/postgresql.nix`\](file:///home/yi/the.files/nixos/modules/services/postgresql.nix), `pg_hba.conf` grants passwordless `trust` to the entire VPN CIDR: `host all all ${allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr} trust`.
   - In \[`modules/services/samba/server.nix`\](file:///home/yi/the.files/nixos/modules/services/samba/server.nix), `hosts allow` permits `${vpnCidr}` alongside `${lanCidr}` and `${lanCidr6}`.
   - In \[`modules/services/samba/client.nix`\](file:///home/yi/the.files/nixos/modules/services/samba/client.nix), CIFS mounts are **already migrated**: `serverIp` is set to `yifuwuqi.network.lan.ipv4.host` (`10.42.0.2`), with no VPN daemon dependencies.

1. **Firewall & Container Isolation**:

   - In \[`hosts/yifuwuqi/networking/firewall.nix`\](file:///home/yi/the.files/nixos/hosts/yifuwuqi/networking/firewall.nix), `trustedHostDestinations` permits container egress to `addresses.network.vpn.ipv4.host` in addition to LAN hosts.

1. **Peerings & Roaming Nodes (Intentional Tailscale Usage)**:

   - **`lan-mouse`**: As documented in \[`docs/src/hardware/lan-mouse.md`\](file:///home/yi/the.files/nixos/docs/src/hardware/lan-mouse.md), KVM traffic between `yitaishi` and `yixiaoqing` is bound to Tailscale (`100.x.x.x`). This is required because `yixiaoqing` is a laptop with no static LAN reservation that frequently roams across networks, and `yitaishi` does not have a static LAN IP assigned in `modules/addresses.nix`.
   - **Distributed Builds**: \[`modules/distributed-builds.nix`\](file:///home/yi/the.files/nixos/modules/distributed-builds.nix) targets `yitaishi` via its VPN address because `yitaishi`'s sshd binds strictly to VPN interfaces and `hosts.yitaishi` does not possess a static `network.lan` block in `addresses.nix`.
   - **Obsolete Components**: `llama-swap-amdgpu` (port 50052) was completely removed from the gang and replaced by local `llama-cpp-node`. \[`modules/services/openvscode-server.nix`\](file:///home/yi/the.files/nixos/modules/services/openvscode-server.nix) is unimported dead code replaced by \[`modules/services/opencode.nix`\](file:///home/yi/the.files/nixos/modules/services/opencode.nix).

______________________________________________________________________

## Decisions

### 1. Subnet Router as the Single Remote Ingress Boundary

- `yirukou` advertises `10.42.0.0/24` to Tailscale with default SNAT masquerade enabled.
- Remote devices access homelab services (Nginx, Samba, PostgreSQL) through their LAN IP addresses (`10.42.0.1`, `10.42.0.2`) over the subnet route.
- Remove `100.64.0.0/10` from service allowlists. Remote traffic arrives at host services SNAT'd as `10.42.0.1` and matches LAN allowlists.

### 2. Restrict Reverse Proxy Access to LAN Subnets

- Remove `allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr` from `trustedProxyCidrs` in \[`modules/services/nginx-proxy.nix`\](file:///home/yi/the.files/nixos/modules/services/nginx-proxy.nix).
- Delete the legacy `addresses.network.vpn.ipv4.host` virtual host block.

### 3. Restrict PostgreSQL Authentication to LAN

- Update `modules/services/postgresql.nix` `pg_hba.conf` to replace `${allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr}` with `${allAddresses.hosts.yirukou.network.lan.ipv4.cidr}` (`10.42.0.0/24`).

### 4. Restrict Samba Access to LAN

- Remove `vpnCidr` from `modules/services/samba/server.nix`, restricting `hosts allow` to `${lanCidr} ${lanCidr6} 127.0.0.1 localhost ::1`.

### 5. Clean Up Dead & Legacy Modules

- Remove `addresses.network.vpn.ipv4.host` from `modules/services/cockpit.nix` `allowed-origins`.
- Remove `allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr` from `modules/services/forgejo.nix` webhook allowlist.
- Remove `addresses.network.vpn.ipv4.host` from `hosts/yifuwuqi/networking/firewall.nix` `trustedHostDestinations`.
- Delete unimported legacy module `modules/services/openvscode-server.nix`.

### 6. Preserve Tailscale for Dynamic and Roaming Peerings

- Retain Tailscale IPs for `lan-mouse` and `modules/distributed-builds.nix` until/unless dynamic nodes (`yitaishi`, `yixiaoqing`) receive static LAN allocations and static LAN listeners.

______________________________________________________________________

## Phases

### Phase 1: Storage and Database Services

1. In \[`modules/services/postgresql.nix`\](file:///home/yi/the.files/nixos/modules/services/postgresql.nix), replace VPN CIDR with LAN CIDR in `authentication`.
1. In \[`modules/services/samba/server.nix`\](file:///home/yi/the.files/nixos/modules/services/samba/server.nix), remove `vpnCidr` from `hosts allow`.

### Phase 2: Web, Proxy, and Development Services

1. In \[`modules/services/nginx-proxy.nix`\](file:///home/yi/the.files/nixos/modules/services/nginx-proxy.nix), remove `yifuwuqi.network.vpn.ipv4.cidr` from `trustedProxyCidrs` and delete the `"${addresses.network.vpn.ipv4.host}"` virtual host.
1. In \[`modules/services/forgejo.nix`\](file:///home/yi/the.files/nixos/modules/services/forgejo.nix), remove `yifuwuqi.network.vpn.ipv4.cidr` from `trustedCidrs`.
1. In \[`modules/services/cockpit.nix`\](file:///home/yi/the.files/nixos/modules/services/cockpit.nix), remove VPN URLs from `allowed-origins`.
1. Delete unimported file \[`modules/services/openvscode-server.nix`\](file:///home/yi/the.files/nixos/modules/services/openvscode-server.nix).

### Phase 3: Host Firewall Rules

1. In \[`hosts/yifuwuqi/networking/firewall.nix`\](file:///home/yi/the.files/nixos/hosts/yifuwuqi/networking/firewall.nix), remove `addresses.network.vpn.ipv4.host` from `trustedHostDestinations`.

### Phase 4: Validation & Evaluation

1. Run `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run` across `yifuwuqi` and `yirukou`.
1. Verify that services build and evaluate cleanly without syntax errors or broken references.

______________________________________________________________________

## Rollout Order

1. Apply changes to `modules/services/postgresql.nix`, `modules/services/samba/server.nix`, `modules/services/forgejo.nix`, `modules/services/cockpit.nix`, and `hosts/yifuwuqi/networking/firewall.nix`.
1. Apply changes to `modules/services/nginx-proxy.nix`.
1. Delete `modules/services/openvscode-server.nix`.
1. Evaluate configurations using `nix build --dry-run`.
1. Deploy to `yifuwuqi`:
   ```bash
   nixos-rebuild switch --flake .#yifuwuqi
   ```
1. Deploy to `yirukou`:
   ```bash
   nixos-rebuild switch --flake .#yirukou --target-host yirukou --use-remote-sudo
   ```
1. Verify service reachability over LAN (`10.42.0.x`) and via Tailscale subnet routing.

______________________________________________________________________

## Open Questions

None. The boundary rules are well-defined: server daemons trust the LAN segment, while client devices roaming outside the LAN access all services through the `yirukou` Tailscale subnet router.
