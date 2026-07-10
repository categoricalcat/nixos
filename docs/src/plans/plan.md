## Goal Description

Deploy the full *Arr stack (Radarr, Sonarr, Lidarr, Readarr, Prowlarr, Bazarr) and a download client (qBittorrent) natively on the `yifuwuqi` server. The stack will be heavily sandboxed using `systemd` to ensure maximum security, restricting filesystem access exclusively to their own configuration directories and the `/persist/media` path. Network-wise, the applications will be exposed securely via the Nginx proxy on `yirukou`, restricted so they are only accessible from the LAN and VPN (Netbird).

## User Review Required
>
> [!IMPORTANT]
> **Download Client**: I have proposed `qBittorrent` as the download client since it integrates perfectly with the Arr stack and is widely used. If you prefer `Transmission` or `SABnzbd` (for Usenet), let me know and I will adjust the configuration.

## Open Questions

None at this time. We have aligned on the core requirements.

## Proposed Changes

---

### `modules/addresses.nix`

Define the domains and ports for the full suite under `hosts.yifuwuqi.services`.

#### [MODIFY] `modules/addresses.nix`

```diff
       services = {
+        radarr = { domain = "radarr.fufu.land"; port = 7878; };
+        sonarr = { domain = "sonarr.fufu.land"; port = 8989; };
+        lidarr = { domain = "lidarr.fufu.land"; port = 8686; };
+        readarr = { domain = "readarr.fufu.land"; port = 8787; };
+        prowlarr = { domain = "prowlarr.fufu.land"; port = 9696; };
+        bazarr = { domain = "bazarr.fufu.land"; port = 6767; };
+        qbittorrent = { domain = "torrent.fufu.land"; port = 8080; };
         grafana = {
```

---

### `modules/services/arr.nix`

Create the core module to enable all services, set up the `media` group, and apply strict `systemd` sandboxing.

#### [NEW] `modules/services/arr.nix`

```nix
{ pkgs, lib, ... }:

let
  # Common hardening for all media apps
  mediaHardening = {
    serviceConfig = {
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      PrivateTmp = true;
      # Allow apps to only write to their state dir and the shared media dir
      ReadWritePaths = [ "/persist/media" ];
      
      # Network Isolation: Block access to local networks to prevent lateral movement.
      # Allow localhost so the Nginx proxy can reach them and they can talk to each other.
      IPAddressDeny = [ "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "100.64.0.0/10" ];
      IPAddressAllow = [ "127.0.0.1" ];
    };
  };
in
{
  # Shared group for media files
  users.groups.media = {};

  # Ensure the media directory exists with proper ownership
  systemd.tmpfiles.rules = [
    "d /persist/media 0775 root media - -"
  ];

  services.radarr = { enable = true; group = "media"; };
  systemd.services.radarr = lib.mkMerge [ mediaHardening { serviceConfig.ReadWritePaths = [ "/var/lib/radarr" ]; } ];

  services.sonarr = { enable = true; group = "media"; };
  systemd.services.sonarr = lib.mkMerge [ mediaHardening { serviceConfig.ReadWritePaths = [ "/var/lib/sonarr" ]; } ];

  services.lidarr = { enable = true; group = "media"; };
  systemd.services.lidarr = lib.mkMerge [ mediaHardening { serviceConfig.ReadWritePaths = [ "/var/lib/lidarr" ]; } ];

  services.readarr = { enable = true; group = "media"; };
  systemd.services.readarr = lib.mkMerge [ mediaHardening { serviceConfig.ReadWritePaths = [ "/var/lib/readarr" ]; } ];

  services.prowlarr = { enable = true; };
  systemd.services.prowlarr = lib.mkMerge [ mediaHardening { serviceConfig.ReadWritePaths = [ "/var/lib/prowlarr" ]; } ];

  services.bazarr = { enable = true; group = "media"; };
  systemd.services.bazarr = lib.mkMerge [ mediaHardening { serviceConfig.ReadWritePaths = [ "/var/lib/bazarr" ]; } ];

  services.qbittorrent = { enable = true; group = "media"; };
  systemd.services.qbittorrent = lib.mkMerge [ mediaHardening { serviceConfig.ReadWritePaths = [ "/var/lib/qbittorrent" ]; } ];
}
```

---

### `modules/services/nginx-proxy.nix`

Add proxy entries for the suite, using the existing `restrictedProxyConfig` to ensure they are only accessible via LAN and VPN.

#### [MODIFY] `modules/services/nginx-proxy.nix`

```diff
       # Cockpit host management — proxied to yifuwuqi
       "${yifuwuqiServices.cockpit.domain}" = {
         useACMEHost = "fufu.land";
         forceSSL = true;
         locations."/" = {
           proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.cockpit.port}";
           proxyWebsockets = true;
           extraConfig = restrictedProxyConfig;
         };
       };

+      # Media Stack (Restricted to LAN/VPN)
+      "${yifuwuqiServices.radarr.domain}" = { useACMEHost = "fufu.land"; forceSSL = true; locations."/" = { proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.radarr.port}"; proxyWebsockets = true; extraConfig = restrictedProxyConfig; }; };
+      "${yifuwuqiServices.sonarr.domain}" = { useACMEHost = "fufu.land"; forceSSL = true; locations."/" = { proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.sonarr.port}"; proxyWebsockets = true; extraConfig = restrictedProxyConfig; }; };
+      "${yifuwuqiServices.lidarr.domain}" = { useACMEHost = "fufu.land"; forceSSL = true; locations."/" = { proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.lidarr.port}"; proxyWebsockets = true; extraConfig = restrictedProxyConfig; }; };
+      "${yifuwuqiServices.readarr.domain}" = { useACMEHost = "fufu.land"; forceSSL = true; locations."/" = { proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.readarr.port}"; proxyWebsockets = true; extraConfig = restrictedProxyConfig; }; };
+      "${yifuwuqiServices.prowlarr.domain}" = { useACMEHost = "fufu.land"; forceSSL = true; locations."/" = { proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.prowlarr.port}"; proxyWebsockets = true; extraConfig = restrictedProxyConfig; }; };
+      "${yifuwuqiServices.bazarr.domain}" = { useACMEHost = "fufu.land"; forceSSL = true; locations."/" = { proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.bazarr.port}"; proxyWebsockets = true; extraConfig = restrictedProxyConfig; }; };
+      "${yifuwuqiServices.qbittorrent.domain}" = { useACMEHost = "fufu.land"; forceSSL = true; locations."/" = { proxyPass = "http://${yifuwuqiLan}:${toString yifuwuqiServices.qbittorrent.port}"; proxyWebsockets = true; extraConfig = restrictedProxyConfig; }; };
```

---

### `hosts/yifuwuqi/services.nix`

Import the module.

#### [MODIFY] `hosts/yifuwuqi/services.nix`

```diff
   imports = [
     ../../modules/services/samba/server.nix
     ../../modules/services/avahi.nix
     ../../modules/services/openssh.nix
+    ../../modules/services/arr.nix
```

## Verification Plan

### Automated Tests

* Dry-build the `yifuwuqi` and `yirukou` flakes to ensure the configuration is valid:

  ```bash
  nixos-rebuild dry-build --flake .#yirukou
  nixos-rebuild dry-build --flake .#yifuwuqi
  ```

### Manual Verification

1. Open `radarr.fufu.land` while connected to Netbird or LAN. It should load.
2. Disconnect from Netbird and step off the LAN (e.g. mobile data). `radarr.fufu.land` should return a 403 Forbidden or timeout, verifying the `restrictedProxyConfig` is working.
3. **CRITICAL SECURITY STEP:** Log into the qBittorrent WebUI (`torrent.fufu.land`), go to Options -> Advanced -> **Network Interface**, and select your VPN interface (e.g., `wt0` for Netbird). This ensures that if the VPN disconnects, qBittorrent instantly drops all connections and will not leak your real IP.
4. Add a download in Radarr and ensure it successfully sends to qBittorrent and moves to `/persist/media` upon completion, verifying group permissions and systemd sandboxing.
