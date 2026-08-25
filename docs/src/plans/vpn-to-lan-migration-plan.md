# VPN to LAN Migration Plan

This document outlines the required changes to migrate all services from a dual-hosted architecture (where services bind to and explicitly trust VPN IPs) to a LAN-only architecture. In this new architecture, services will listen exclusively on local LAN interfaces, and the VPN will act as a subnet router to provide remote access to the LAN.

## Design Decisions and Prerequisites

1. **Subnet Routing vs Client IPs**: To fully remove VPN IPs from service configurations (like `trustedProxyCidrs`), the VPN subnet router must perform SNAT (IP masquerading) so that incoming remote traffic appears to originate from the router's LAN IP. If SNAT is not used, services will see the original VPN client IPs, which means the VPN CIDRs must remain in access control lists (Samba, Nginx, PostgreSQL, Forgejo).
1. **Subnet Router Setup**: You will need to configure Netbird (or Tailscale) to advertise the LAN route (e.g., `192.168.1.0/24`) and ensure your client devices are configured to route LAN traffic through the VPN.

## Required Configuration Changes

Below is a comprehensive list of all NixOS modules and host files that currently reference VPN (or Tailscale) IPs and need to be updated to use LAN IPs.

### 1. Nginx and Proxy Configs

- **`modules/services/nginx-proxy.nix`**:
  - Remove `allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr` (and the commented-out Tailscale CIDR) from `trustedProxyCidrs`.
  - Delete the virtual host block that binds explicitly to `addresses.network.vpn.ipv4.host`.
- **`modules/services/forgejo.nix`**:
  - Remove the VPN and Tailscale CIDRs from the `trustedProxyCidrs` list inside the Forgejo module.

### 2. Network and Firewall Rules

- **`hosts/yifuwuqi/networking/firewall.nix`**:
  - Remove `addresses.network.vpn.ipv4.host` from the `trustedHostDestinations` set.
- **`hosts/yitaishi/services.nix`**:
  - Remove the firewall rule that explicitly opens TCP port 50052 on the VPN interface (`networking.firewall.interfaces.${addresses.network.vpn.interface}.allowedTCPPorts`).

### 3. Storage and Database Services

- **`modules/services/postgresql.nix`**:
  - Update `pg_hba.conf` authentication to trust the LAN CIDR instead of the VPN CIDR.
- **`modules/services/samba/server.nix`**:
  - Remove `vpnCidr` from the `hosts allow` directive.
- **`modules/services/samba/client.nix`**:
  - Update the CIFS mount definitions (`/mnt/smb/share`, `/mnt/smb/the.files`) to point to `yifuwuqi.network.lan.ipv4.host` instead of the VPN/Tailscale IP.
  - Remove dependencies on `netbird.service` and `tailscaled.service` since the mounts will go over the LAN interface natively.

### 4. Distributed Compute and AI

- **`hosts/yifuwuqi/services.nix`**:
  - Update the `llama-swap-amdgpu` `rpcPeers` to use the LAN IP (`allAddresses.hosts.yitaishi.network.lan.ipv4.host:50052`) instead of `yitaishiVpn`.
- **`hosts/yitaishi/services.nix`**:
  - Change the `llama-swap-amdgpu` `rpcServer.listenAddress` to bind to the LAN IP or `0.0.0.0` instead of the VPN IP.
- **`modules/distributed-builds.nix`**:
  - Change the SSH `HostName` for distributed Nix builders to use `network.lan.ipv4.host` instead of `network.vpn.ipv4.host`.

### 5. Management and Developer Tools

- **`modules/services/cockpit.nix`**:
  - Remove the VPN IP from the allowed `Origins` list for the Cockpit web interface.
- **`modules/services/openvscode-server.nix`**:
  - Change the server's listen host to use the LAN IP (`addresses.network.lan.ipv4.host`) instead of the VPN IP.

### 6. Peripherals (Lan-Mouse)

- **`hosts/yitaishi/services.nix`**:
  - Update the `lan-mouse` settings to connect to `yixiaoqing.network.lan.ipv4.host` instead of the VPN IP.
- **`hosts/yixiaoqing/configuration.nix`**:
  - Update the `lan-mouse` settings to connect to `yitaishi.network.lan.ipv4.host` instead of the VPN IP.

## Verification

Once these changes are applied:

1. Ensure the Netbird subnet router is active and routes are accepted by clients.
1. Disconnect a client from the local LAN (e.g., connect to a cellular hotspot), enable Netbird, and attempt to access `*.fufu.land` and internal services via their LAN IP addresses.
1. Verify that `lan-mouse`, distributed Nix builds, and `llama-swap` can communicate seamlessly across the LAN interfaces.
