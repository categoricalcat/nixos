# Proton-gated Arr Stack

## Goal

Deploy Radarr, Sonarr, Lidarr, Readarr, Prowlarr, and Bazarr natively on
`yifuwuqi`. Run qBittorrent in a Podman namespace shared only with Gluetun,
which routes torrent traffic through Proton VPN over WireGuard.

Keep NetBird as the private host mesh. Do not use NetBird or Tailscale as the
qBittorrent egress VPN.

```mermaid
flowchart LR
  Browser[LAN_or_NetBird_browser] --> Nginx[Nginx_yirukou]
  Nginx --> Arr[Native_Arr_services]
  Nginx --> Qbit[qBittorrent_WebUI]
  Arr -->|localhost_API| Qbit
  Qbit -->|shared_network_namespace| Gluetun[Gluetun_ProtonVPN]
  Gluetun -->|WireGuard_NAT_PMP| Proton[Proton_P2P_exit]
  Proton --> Peers[Torrent_peers]
  Arr --> Media[/persist/media]
  Qbit --> Media
```

## Required Before Deployment

- Proton plan with P2P and port-forwarding support.
- Proton WireGuard private key generated from the Proton account.
- A qBittorrent WebUI password converted to qBittorrent's PBKDF2 format.
- Capacity and backup policy confirmed for `/persist/media`; it is currently
  part of yifuwuqi's root filesystem, not a separate declared mount.

## Security Model

- qBittorrent does not use the host network, NetBird `wt0`, or a host-published
  torrent port.
- Only Gluetun receives `NET_ADMIN` and `/dev/net/tun`; neither container is
  privileged and neither receives the Podman socket.
- qBittorrent shares Gluetun's network namespace. Gluetun's firewall blocks
  traffic when Proton is unavailable.
- Proton's dynamically assigned port is synchronized to qBittorrent through
  its loopback-only WebUI API. qBittorrent binds torrent traffic to Gluetun's
  tunnel interface; it is set to loopback when the forwarding lease is lost.
- Nginx on yirukou remains the sole browser ingress. An early yifuwuqi nftables
  rule permits backend UI traffic only from yirukou's LAN address, before broad
  trusted-interface and Podman forwarding rules can bypass the proxy.
- Browser access remains limited to LAN and NetBird by
  `restrictedProxyConfig`. qBittorrent retains its own WebUI credential.

## Proposed Changes

### [MODIFY] [modules/addresses.nix](/home/yi/the.files/nixos/modules/addresses.nix)

Add `radarr`, `sonarr`, `lidarr`, `readarr`, `prowlarr`, `bazarr`, and
`qbittorrent` records under `hosts.yifuwuqi.services` with domains under
`fufu.land` and ports `7878`, `8989`, `8686`, `8787`, `9696`, `6767`, and
`8080`, respectively.

Use those records as the single source of truth for the native service ports,
Nginx upstreams, and qBittorrent WebUI mapping.

### [NEW] [modules/services/arr.nix](/home/yi/the.files/nixos/modules/services/arr.nix)

Enable the six native Arr services only; qBittorrent is not a NixOS
`services.qbittorrent` unit.

- Create a fixed `media` group and setgid, group-writable directories:
  - `/persist/media/downloads/incomplete`
  - `/persist/media/downloads/complete`
  - `/persist/media/movies`
  - `/persist/media/tv`
  - `/persist/media/music`
  - `/persist/media/books`
- Run Radarr, Sonarr, Lidarr, Readarr, and Bazarr with the `media` group and
  `UMask = "0002"`. Prowlarr does not receive media access.
- Set every listener port explicitly from the address registry.
- Apply compatible per-service hardening: strict read-only system paths, each
  real state directory as writable, and `/persist/media` as the only shared
  writable path.
- Use `PrivateUsers = "identity"` for shared-media services so the configured
  media UID/GID remains usable while retaining user-namespace capability
  isolation.
- Do not apply `IPAddressDeny`/`IPAddressAllow` to Arr services. They require
  Internet access for metadata and indexers, and those settings would also
  interfere with the remote yirukou proxy.

### [NEW] [modules/services/qbittorrent-vpn.nix](/home/yi/the.files/nixos/modules/services/qbittorrent-vpn.nix)

Declare the Gluetun and qBittorrent OCI containers on the existing rootful
Podman backend.

#### Gluetun

- Load the `tun` kernel module and grant only `NET_ADMIN` plus `/dev/net/tun`.
- Configure Proton WireGuard with:
  - `VPN_SERVICE_PROVIDER=protonvpn`
  - `VPN_TYPE=wireguard`
  - `PORT_FORWARD_ONLY=on`
  - `VPN_PORT_FORWARDING=on`
  - the WireGuard private key from a runtime SOPS environment file
- Disable IPv6 inside the shared namespace unless it is proven routed by Proton.
- Expose only qBittorrent's WebUI port:
  - `127.0.0.1:8080` for native Arr API calls
  - `10.42.0.2:8080` for yirukou's Nginx upstream
- Do not publish the torrent port on yifuwuqi. Gluetun opens Proton's
  dynamically forwarded TCP/UDP port inside the tunnel.
- Set health-based startup and bind qBittorrent's unit lifecycle to Gluetun so
  qBittorrent stops before its gateway namespace is removed or restarted.

#### qBittorrent

- Use the LinuxServer qBittorrent image with a fixed non-root host UID and the
  `media` GID, `PUID`/`PGID`, and `UMASK=002`.
- Join Gluetun with `--network=container:gluetun`.
- Mount only:
  - a dedicated qBittorrent config volume under
    `/var/lib/container-volumes`
  - `/persist/media:/persist/media`
- Set the download paths under `/persist/media/downloads` so host and
  container paths are identical. This avoids Arr Remote Path Mappings and
  preserves hardlink/atomic-import behaviour.
- Seed the WebUI config from runtime SOPS material. Enable loopback-only API
  auth bypass for Gluetun's port-sync command; external users still authenticate
  with the qBittorrent WebUI credential.
- Use Gluetun's documented port-forward `UP_COMMAND` and `DOWN_COMMAND` to
  update qBittorrent's live listen port, disable random/UPnP selection, and
  bind it to the active VPN interface.

### [MODIFY] [secrets/.secrets.example.yaml](/home/yi/the.files/nixos/secrets/.secrets.example.yaml)

Document placeholders for:

- Proton WireGuard private key.
- qBittorrent WebUI password/PBKDF2 bootstrap material.

Declare corresponding SOPS secrets and templates in
[modules/services/qbittorrent-vpn.nix](/home/yi/the.files/nixos/modules/services/qbittorrent-vpn.nix).
Generated environment/config files must stay at runtime paths and out of the
Nix store.

### [MODIFY] [hosts/yifuwuqi/services.nix](/home/yi/the.files/nixos/hosts/yifuwuqi/services.nix)

Import `arr.nix` and `qbittorrent-vpn.nix`.

The existing Podman foundation in
[modules/virtualisation/podman.nix](/home/yi/the.files/nixos/modules/virtualisation/podman.nix)
remains unchanged.

### [MODIFY] [modules/services/nginx-proxy.nix](/home/yi/the.files/nixos/modules/services/nginx-proxy.nix)

Add TLS vhosts for all seven domains. Reuse the wildcard certificate,
WebSocket proxying, and `restrictedProxyConfig`. qBittorrent's upstream is
the yifuwuqi LAN WebUI binding, while native Arr services use their explicit
backend ports.

### [MODIFY] [hosts/yifuwuqi/networking/firewall.nix](/home/yi/the.files/nixos/hosts/yifuwuqi/networking/firewall.nix)

Add an early nftables ingress guard for all seven backend UI ports:

- Permit yirukou's LAN address (`10.42.0.1`) to reach the yifuwuqi backend
  bindings.
- Drop direct LAN and NetBird access before existing trusted-interface rules
  accept it.
- Preserve loopback access for local Arr-to-qBittorrent API traffic.

## Bootstrap

1. Deploy and authenticate to each UI through Nginx.
2. Configure `/persist/media` root folders in Radarr, Sonarr, Lidarr, and
   Readarr.
3. Configure qBittorrent's complete/incomplete directories under
   `/persist/media/downloads`.
4. Add qBittorrent as each Arr download client through `127.0.0.1:8080`.
5. Add Prowlarr application integrations and indexers.
6. Verify qBittorrent reports the Gluetun interface and the current Proton
   forwarded port. Do not manually select `wt0`.

## Verification

### Automated

```bash
nixos-rebuild dry-build --flake .#yifuwuqi
nixos-rebuild dry-build --flake .#yirukou
```

- Inspect generated Podman units and mounts: only Gluetun has tunnel
  privileges; qBittorrent has no host network, Podman socket, or added
  capabilities.
- Confirm Gluetun starts healthy before qBittorrent.

### Manual

1. Confirm all `*.fufu.land` UIs work from LAN and NetBird, and fail from an
   unapproved source.
2. Confirm direct yifuwuqi backend UI ports are dropped except for yirukou and
   local loopback clients.
3. Confirm qBittorrent's public egress IP is Proton's and that DNS and IPv6 do
   not leave the shared namespace outside the tunnel.
4. Restart or stop Gluetun; qBittorrent must lose Internet connectivity and
   stop/restart with its gateway.
5. Confirm Proton's forwarded port matches qBittorrent's active TCP/UDP listen
   port, including after a reconnect.
6. Complete one import for each media type and verify group-writable ownership,
   hardlink/atomic import behaviour, and Arr/Prowlarr/qBittorrent integration.
