# Service Security Architecture & Defense-in-Depth Plan

## Objective

Eliminate the reliance on manual, brittle `nftables` tables and priority-override drop chains (`backend-ui-guard`, `valkey-guard`, `container-isolation`) for securing host services across the infrastructure. Transition to a modern, layered **defense-in-depth / zero-trust** architecture that uses:

1. **Default-Deny Network Boundary**: Invert the "trusted interface" anti-pattern so unexposed ports are closed by default at the kernel layer.
1. **Socket & Loopback Binding Isolation**: Bind internal daemons to `127.0.0.1` or UNIX domain sockets (`/run/...`) where external network packets cannot reach them.
1. **Cryptographic Identity & Transport Security**: Authenticate and encrypt inter-host traffic via Mutual TLS (mTLS) or WireGuard Cryptokey Routing instead of brittle IP allowlisting.
1. **Application-Layer Authentication**: Enforce native credentials/passwords on sensitive services like Valkey/Redis.
1. **Systemd eBPF Cgroup Sandboxing**: Use declarative `IPAddressAllow=` / `IPAddressDeny=` at the systemd unit level for granular isolation without manual nftables scripting.
1. **Isolated Container Networks**: Use Podman native `internal = true` bridge networks for container isolation.

______________________________________________________________________

## Current State & Why nftables Became a Crutch

Currently in \[`hosts/yifuwuqi/networking/firewall.nix`\](file:///home/yi/the.files/nixos/hosts/yifuwuqi/networking/firewall.nix):

1. **The "Trusted Interface" Inversion**: `eno1` (the physical LAN interface) is marked in `networking.firewall.trustedInterfaces = [ "eno1" "tailscale0" ]`. This tells the NixOS firewall to accept **all incoming TCP/UDP connections on the LAN interface by default**.
1. **The "Whack-a-Mole" Drop Chains**: Because `eno1` is trusted, every service listening on `0.0.0.0` or `10.42.0.2` is automatically exposed to any device on the LAN. To mitigate this:
   - `backend-ui-guard` was created with `priority -10` to intercept and `counter drop` connections to 9 Arr/media web UI ports unless coming from `10.42.0.1`.
   - `valkey-guard` was created with `priority -10` to drop unauthenticated Valkey cache DB connections unless coming from `127.0.0.1` or `10.42.0.1`.
   - `container-isolation` was created with raw forward chains to drop container subnet forwarding into private subnets.
1. **Fragility of L3/L4 Packet Filtering**:
   - IP-based allowlisting (`10.42.0.1`) provides no cryptographic identity, encryption, or integrity.
   - Adding or modifying a service requires synchronized changes in `addresses.nix`, the service definition, and custom nftables hook scripts.
   - If a custom nftables table fails to load or has a typo in port lists, services fail open.

______________________________________________________________________

## Architectural Comparison: nftables vs Modern Alternatives

| Requirement                                                      | Current (nftables Hack)                                                          | Proposed Alternative                                                      | Primary Benefit                                                                     |
| :--------------------------------------------------------------- | :------------------------------------------------------------------------------- | :------------------------------------------------------------------------ | :---------------------------------------------------------------------------------- |
| **Backend Web UIs** (Radarr, Sonarr, etc.)                       | Listen on `0.0.0.0`, dropped by `backend-ui-guard` nftables hook                 | Bind to `127.0.0.1` + Local Backend Proxy or mTLS upstream                | Physical impossibility of external access; no firewall rules needed                 |
| **Valkey / Redis DNS Cache**                                     | Listen on `10.42.0.2:6379` with `--protected-mode no`, dropped by `valkey-guard` | Valkey native password/auth + Unix sockets for local exporters + TLS/mTLS | Authenticated at application layer; cache poisoning prevented regardless of network |
| **Inter-Host Traffic** (`yirukou` $\\leftrightarrow$ `yifuwuqi`) | Plaintext HTTP over LAN, IP allowlisted by nftables                              | 3-Tier Mutual TLS (mTLS) or WireGuard Cryptokey Routing                   | Full transport encryption, cryptographic client identity, zero IP spoofing risk     |
| **LAN Default Security**                                         | `trustedInterfaces = ["eno1"]` (all ports open by default)                       | Standard NixOS Default-Deny (`allowedTCPPorts = [...]`)                   | Zero unexpected port exposure; no negative drop rules needed                        |
| **Service-Level Network Constraints**                            | Global nftables tables                                                           | Systemd unit `IPAddressAllow=` / `IPAddressDeny=` (eBPF)                  | Declarative per-service cgroup firewall managed natively by systemd                 |
| **Container Subnet Isolation**                                   | Manual nftables forward drop chains                                              | Podman `internal = true` bridge networks & rootless containers            | Handled cleanly in container engine without host firewall rules                     |

______________________________________________________________________

## Decisions

### 1. Invert the Firewall Model to Default-Deny

- Remove `eno1` from `networking.firewall.trustedInterfaces` on `yifuwuqi`.
- Only explicitly declare the required external ports in `networking.firewall.allowedTCPPorts` / `interfaces."eno1".allowedTCPPorts` (such as SSH `24212` and AdGuard Home DNS `3333`/`53`).
- **Impact**: All backend services (ports 7878, 8989, 8686, 8787, 9696, 6767, 8080, 6379, etc.) become inaccessible from the LAN by default. `backend-ui-guard` and `valkey-guard` can be completely deleted.

### 2. Socket-Level & Localhost Isolation

- Services that do not need to be directly reached across the network (e.g. Recyclarr, Slskd web UI, SearXNG internal backends) will bind strictly to `127.0.0.1` or UNIX sockets (`/run/<service>/<service>.sock`).
- Local scrapers (e.g., Redis Prometheus exporter) already use `/run/redis/redis.sock`.
- Services bound to `127.0.0.1` cannot receive packets from external interfaces because Linux kernel martian filtering drops external packets targeting `127.0.0.0/8`.

### 3. Mutual TLS (mTLS) for Inter-Host Proxying & Monitoring

- As outlined in \[`docs/src/plans/mtls-architecture-plan.md`\](file:///home/yi/the.files/nixos/docs/src/plans/mtls-architecture-plan.md):
  - `yirukou` Nginx connects to `yifuwuqi` over TLS using an internal client certificate (`yirukou-proxy.crt`).
  - A TLS-terminating Nginx virtual host on `yifuwuqi` validates the client certificate against `fufu-service-ca.crt` (`sslVerifyClient = "on"`).
  - Unauthenticated connections are dropped at the TLS handshake level before any HTTP request reaches backend daemons.

### 4. Valkey / DNS Cache Security

- If Valkey must be queried across hosts by Unbound on `yirukou`:
  - Option A: Require native authentication (`requirepass` or Valkey ACLs).
  - Option B: Route inter-host DNS cache traffic through an encrypted WireGuard/mTLS channel.
  - Option C: Enable local Unbound caches with DNS prefetching, using Valkey only locally on `yifuwuqi` via UNIX domain socket `/run/redis/redis.sock`.

### 5. Native Systemd Cgroup / eBPF Sandboxing

- Where fine-grained per-service IP filtering is needed, configure `serviceConfig.IPAddressAllow` and `serviceConfig.IPAddressDeny` inside the systemd unit.
- Systemd compiles these into BPF programs attached directly to the service's cgroup, enforcing socket-level filtering in the kernel without polluting the global nftables table.

______________________________________________________________________

## Phases & Implementation Strategy

```text
┌─────────────────────────────────────────────────────────────┐
│    Phase 1: Default-Deny & Remove trustedInterfaces         │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│    Phase 2: Localhost & Unix Socket Binding                 │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│    Phase 3: Valkey Auth / Unix Socket Hardening             │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│    Phase 4: Inter-Host Ingress & mTLS                       │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│    Phase 5: Container Bridge Isolation & Clean Up nftables  │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│         Fully Hardened Zero-Trust Architecture              │
└─────────────────────────────────────────────────────────────┘
```

### Phase 1: Switch to Default-Deny & Delete `backend-ui-guard`

1. In \[`hosts/yifuwuqi/networking/firewall.nix`\](file:///home/yi/the.files/nixos/hosts/yifuwuqi/networking/firewall.nix):
   - Remove `"eno1"` from `networking.firewall.trustedInterfaces`.
   - Explicitly list necessary open ports under `networking.firewall.interfaces."eno1".allowedTCPPorts` (e.g. SSH, AdGuard Home DNS).
   - Delete the `backend-ui-guard` nftables table.
1. Verify:
   - Backend UI ports (7878, 8989, etc.) are immediately dropped by the default-deny firewall for general LAN clients.
   - Legitimate traffic through `yirukou` proxy reaches services via the designated ingress.

### Phase 2: Localhost & UNIX Domain Socket Binding

1. Ensure Arr services, homepage, and internal APIs bind to `127.0.0.1` where only local processes and proxies need access.
1. For same-host monitoring exporters, ensure all Prometheus exporters connect via `/run/.../*.sock` or `127.0.0.1`.

### Phase 3: Valkey DNS Cache Hardening

1. In \[`modules/services/valkey.nix`\](file:///home/yi/the.files/nixos/modules/services/valkey.nix):
   - Re-enable `protected-mode yes` or configure password authentication via Sops.
   - Delete the `valkey-guard` table in `firewall.nix`.
1. Configure Unbound to authenticate against Valkey, or switch to Unix socket binding on `yifuwuqi` if caching is made host-local.

### Phase 4: Inter-Host mTLS / WireGuard Proxying

1. Implement the 3-tier mTLS design from `mtls-architecture-plan.md`.
1. Terminate backend TLS on `yifuwuqi` requiring client certificates from `yirukou`.
1. Inter-host traffic is now cryptographically secured against spoofing, eavesdropping, and perimeter bypass.

### Phase 5: Container Isolation via Podman Bridge Networks

1. Configure Podman networks with `internal = true` where containers should not route to private destination subnets.
1. Remove the `container-isolation` custom nftables table in `firewall.nix`.

______________________________________________________________________

## Rollout Order

1. **Step 1: Audit all open ports on `yifuwuqi`**: Identify exact ports needed by external clients (SSH, AdGuard, DNS).
1. **Step 2: Remove `eno1` from `trustedInterfaces` & test**: Verify default-deny blocks backend ports cleanly.
1. **Step 3: Remove custom nftables tables (`backend-ui-guard`, `valkey-guard`, `container-isolation`)**: Verify clean, standard NixOS firewall configuration.
1. **Step 4: Deploy Phase 2 of mTLS Architecture Plan**: Enable encrypted, authenticated inter-host proxying between `yirukou` and `yifuwuqi`.

______________________________________________________________________

## Open Questions

1. **Valkey Topology**: Do you prefer keeping a shared Valkey across LAN with password/TLS auth, or running independent Valkey instances on each host via fast UNIX domain sockets?
1. **Ingress Architecture**: For inter-host proxying from `yirukou` to `yifuwuqi`, do you prefer the **mTLS Nginx Upstream** approach (Tier 2 in `mtls-architecture-plan.md`) or a dedicated **WireGuard point-to-point peer** between the two hosts?
1. **Systemd eBPF vs Port Binding**: For local services, are you happy standardizing on `127.0.0.1` binding and UNIX sockets, using systemd `IPAddressAllow` only for edge cases?
