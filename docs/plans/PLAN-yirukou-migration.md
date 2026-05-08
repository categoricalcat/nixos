# Yirukou Migration Plan — Full Cutover Spec

This plan covers the migration from the current ER706W-based `192.168.0.0/24` homelab
to the yirukou-based `10.42.0.0/24` topology with VLAN isolation.

Target: **T1** (yirukou as sole gateway, ER706W as AP-like trunk).

## Table of Contents
1. [Architecture Decisions](#1-architecture-decisions)
2. [Complete Issue Inventory](#2-complete-issue-inventory)
3. [Files to Create](#3-files-to-create)
4. [Files to Modify](#4-files-to-modify)
5. [Migration Phases](#5-migration-phases)
6. [Testing Plan](#6-testing-plan)
7. [Rollback Plan](#7-rollback-plan)

---

## 1. Architecture Decisions

| Decision | Vote | Rationale |
|---|---|---|
| AdGuardHome location | **Solely on yirukou** | Single DNS authority. Remove from yifuwuqi entirely. |
| Yirukou AdGuard DoT/DoH | **Skip for T1** | TLS certs live only on yifuwuqi via ACME. LAN DNS over local wire is acceptable. |
| Tailscale module refactor | **Option A** | Shared module with per-host options (`advertiseRoutes`, `exitNodeHost`, `routingMode`) instead of per-host copies. |
| yifuwuqi firewall ports 53/853 | **Remove** | No DNS running locally after AdGuardHome moves to yirukou. |
| yifuwuqi WireGuard | **Stays commented-out** | Not in scope for T1. |
| yifuwuqi sysctl.nix (IP forwarding) | **Keep** | BBR/TCP tuning still beneficial on a services host; harmless extra sysctls. |
| wan1 activation | **Deferred** | Subnet clash (both ISP modems at 192.168.1.0/24) needs VRF/netns. Not in T1 scope. |
| Container isolation rule for 10.42.0.1 | **Add** | Podman containers on yifuwuqi need DNS access to yirukou (10.42.0.1:53). |

---

## 2. Complete Issue Inventory

### A — Addresses/IP Remapping

| # | File | Line(s) | Change |
|---|---|---|---|
| A1 | `modules/addresses.nix` | 120 | `yifuwuqi.network.lan.ipv4.host` = `"192.168.0.42"` → `"10.42.0.2"` |
| A2 | `modules/addresses.nix` | 123 | `yifuwuqi.network.lan.ipv4.gateway` = `"192.168.0.1"` → `"10.42.0.1"` |
| A3 | `modules/addresses.nix` | 128 | `yifuwuqi.network.sinkhole.ipv4.host` = `"192.168.0.24"` → `"10.42.0.24"` |
| A4 | `modules/addresses.nix` | ~176 | New `yirukou` entry (see §3.1 of PLAN-yirukou.md). Allocate IPs per spec table. |

### B — Hardcoded Literal Values

| # | File | Line(s) | Change |
|---|---|---|---|
| B1 | `modules/services/adguardhome.nix` | 90 | `answer = "192.168.0.42"` → `answer = addresses.network.lan.ipv4.host` |
| B2 | `hosts/yitaishi/networking.nix` | 20 | (commented-out) `"192.168.0.42"` → `"10.42.0.2"` |

### C — Yifuwuqi Networking Cleanup

| # | File | Line(s) | Change |
|---|---|---|---|
| C1 | `hosts/yifuwuqi/networking.nix` | 8 | Remove `../../modules/networking/gateway-failover.nix` import |
| C2 | `modules/networking/interfaces/eno1.nix` | 10 | Remove `config.networkConfig.ManageForeignRoutes = false` |
| C3 | `modules/networking/interfaces/eno1.nix` | 5-8, 29-36 | Remove keepalived-related comments |
| C4 | `modules/networking/interfaces/eno1.nix` | 39 | Remove `MTUBytes = 1492` or set to `1500` |
| C5 | `hosts/yifuwuqi/configuration.nix` | — | Yifuwuqi continues importing `networking.nix` (but now without failover). |

### D — Tailscale Refactoring

| # | File | Line(s) | Change |
|---|---|---|---|
| D1 | `modules/services/tailscale.nix` | 24 | `--advertise-routes=192.168.0.0/24,...` → per-host option |
| D2 | `modules/services/tailscale.nix` | 31 | Hardcoded yifuwuqi exit-node → per-host option |
| D3 | `hosts/yifuwuqi/services.nix` | 44-46 | `useRoutingFeatures = "server"` → `"client"` |
| D4 | `modules/services/tailscale.nix` | — | Add module options: `advertiseRoutes` (list of strings), `exitNodeHost` (nullable string), `routingMode` (enum "client"/"server"/"both") |
| D5 | `hosts/yirukou/services.nix` | — | Set `yirukou.tailscale.routingMode = "server"`; `advertiseRoutes = ["10.42.0.0/24"]` |

### E — AdGuardHome Deployment

| # | File | Line(s) | Change |
|---|---|---|---|
| E1 | `hosts/yirukou/services.nix` | — | Import AdGuardHome. Must bind to `0.0.0.0` or all three gateway IPs (`10.42.0.1`, `10.42.20.1`, `10.42.30.1`). |
| E2 | `modules/services/adguardhome.nix` (or yirukou variant) | — | Skip TLS config (no ACME), or strip TLS block entirely. Plain DNS + DoH on port 53 only. |
| E3 | `modules/services/adguardhome.nix` (rewrites) | 72-113 | Rewrites for `*.fufu.land` point to `10.42.0.2` (yifuwuqi nginx-proxy) via `addresses`; auto-updates. |
| E4 | `hosts/yifuwuqi/services.nix` | 17 | Remove `../../modules/services/adguardhome.nix` import |
| E5 | `hosts/yifuwuqi/configuration.nix` | — | If AdGuardHome removed: also uninstall sops secrets `tokens/deepseek` and `tokens/gemini` if only AdGuard needed them (they don't — nix-access-tokens does). No change. |

### F — Firewall / nftables

| # | File | Line(s) | Change |
|---|---|---|---|
| F1 | `modules/networking/firewall.nix` | 57 | After yifuwuqi IP change to 10.42.0.x, `addresses.network.lan.ipv4.host` auto-updates. Verify the allow rule still works: `ip daddr { ${host}, ${vpn.host}, ${zt.host} } accept`. |
| F2 | `modules/networking/firewall.nix` | 60 | The `192.168.0.0/16` in the drop set no longer matches 10.42.x.x traffic after migration. The `10.0.0.0/8` catch-all still blocks containers from the new 10.42.0.0/24 LAN (correct — only yifuwuqi's own IP is allowed). |
| F3 | `modules/networking/firewall.nix` | 57 | **NEW**: Add `10.42.0.1` (yirukou) to the container isolation allow rule so Podman containers can reach yirukou DNS. Change to: `ip daddr { ${addresses.network.lan.ipv4.host}, ... } accept` |
| F4 | `modules/networking/firewall.nix` | 10, 15 | Remove port 53 from `allowedTCPPorts` and `allowedUDPPorts` if AdGuardHome removed from yifuwuqi. |
| F5 | `modules/networking/firewall.nix` | 70-73 | Remove `nat` section entirely from yifuwuqi (yirukou handles NAT now). Or keep with `enable = false`. |
| F6 | `hosts/yirukou/networking.nix` | — | Full nftables table `yirukou` per PLAN-yirukou-trunk.md §3. Includes: NAT masquerade to WAN, inter-VLAN forward isolation, input chain with ICMP rate limiting (5/sec), bogon filter on WAN, selective logging (LAN only, not Internet noise per addendum). |

### G — Yirukou New Files

| # | File | Purpose |
|---|---|---|
| G1 | `hosts/yirukou/configuration.nix` | Main entry. Imports hardware/boot/networking/services/addresses. Similar pattern to yifuwuqi. |
| G2 | `hosts/yirukou/addresses.nix` | `_module.args.addresses = allAddresses.hosts.yirukou` |
| G3 | `hosts/yirukou/hardware.nix` | NIC rename rules (or kernel names) for wan0, wan1, lan0-3. lspci/nixos-generate-config output. |
| G4 | `hosts/yirukou/boot.nix` | systemd-boot, kernel params. Follow pattern from yifuwuqi/boot.nix. |
| G5 | `hosts/yirukou/networking.nix` | systemd-networkd: bridge br0, VLAN netdevs, DHCPServer, wan0 DHCP. nftables table `yirukou`. Imports sysctl.nix. |
| G6 | `hosts/yirukou/services.nix` | AdGuardHome (with stripped TLS), Tailscale (server mode, adv. 10.42.0.0/24), SSH, Netdata, Cockpit (optional). |

### H — Flake Registration

| # | File | Line(s) | Change |
|---|---|---|---|
| H1 | `flake.nix` | After line 81 | Add `yirukou = nixpkgs-small.lib.nixosSystem { ... inputs, global ... };` with modules: `sops-nix`, `./hosts/yirukou/configuration.nix` |

### I — Integration Details

| # | File | Change |
|---|---|---|
| I1 | Yirukou networking.nix | `networking.nameservers = ["127.0.0.1"]` |
| I2 | Yirukou networking.nix | `services.resolved = { enable = false; extraConfig = "DNSStubListener=no"; }` |
| I3 | Yirukou networking.nix | Add `systemd.network.wait-online.ignoredInterfaces` for LAN ports so boot does not wait for DHCP clients. Alternatively set `systemd.network.wait-online.enable = false` and let systemd handle it. |
| I4 | Yirukou networking.nix | Add `dhcpServerStaticLeases` entries for yifuwuqi (`10.42.0.2`) and ER706W (`10.42.0.254`) once MACs are gathered. |

### J — Service Configuration

| # | File | Change |
|---|---|---|
| J1 | Yirukou services.nix | Import `../../modules/services/openssh.nix`. Listen on `0.0.0.0:22` from br0 + Tailscale per nftables. |
| J2 | Yirukou services.nix | Import `../../modules/services/monitoring/netdata.nix` or `../../modules/services/cockpit.nix` for visibility. |

### K — Container Isolation on Yifuwuqi

| # | File | Line(s) | Change |
|---|---|---|---|
| K1 | `modules/networking/firewall.nix` | 57 | Currently: `ip daddr { ${vpn.host}, ${zt.host}, ${lan.host} } accept`. After migration, `lan.host` = `10.42.0.2`. Containers on yifuwuqi can already reach yifuwuqi. NEED TO ALSO add `10.42.0.1` so containers can reach yirukou DNS. Change daddr set to include `yirukouLan` or add a separate rule. |

### L — SOPS / Secrets

| # | File | Change |
|---|---|---|
| L1 | `/etc/nixos/secrets/secrets.yaml` | Add `public_ip` entry if static IP is used (per PLAN-yirukou-public-ip-addendum.md). |
| L2 | Yirukou needs age SSH key for sops decryption. First-boot manual step. |

---

## 3. Files to Create

```
hosts/yirukou/
├── configuration.nix      # Main entry
├── addresses.nix           # module.args.addresses = allAddresses.hosts.yirukou
├── hardware.nix            # NIC renaming, kernel modules
├── boot.nix                # Bootloader, kernel parameters
├── networking.nix          # systemd-networkd + nftables
└── services.nix            # SSH, AdGuardHome, Tailscale, monitoring
```

### 3.1 Yirukou Address Registry (`modules/addresses.nix` addition)

```
yirukou = rec {
  hostName = "yirukou";

  dns = {
    systemNameservers = [ "127.0.0.1" ];
    domain = "lan";
  };

  network = {
    wan = {
      interface = "wan0";
    };

    wanSpare = {
      interface = "wan1";
    };

    lan = {
      interface = "br0";
      ipv4 = rec {
        cidr = "10.42.0.0/24";
        host = "10.42.0.1";
        prefixLength = 24;
        address = "${host}/${builtins.toString prefixLength}";
      };
    };

    lanMembers = [ "lan0" "lan1" "lan2" ];

    trunk = {
      interface = "lan3";
    };

    vlans = {
      iot = {
        id = 20;
        interface = "lan3.20";
        ipv4 = rec {
          cidr = "10.42.20.0/24";
          host = "10.42.20.1";
          prefixLength = 24;
          address = "${host}/${builtins.toString prefixLength}";
        };
      };
      guest = {
        id = 30;
        interface = "lan3.30";
        ipv4 = rec {
          cidr = "10.42.30.0/24";
          host = "10.42.30.1";
          prefixLength = 24;
          address = "${host}/${builtins.toString prefixLength}";
        };
      };
    };

    tailscale = {
      interface = "tailscale0";
      ipv4 = rec {
        cidr = "100.64.0.0/10";
        host = "100.69.0.2";
        prefixLength = 32;
        address = "${host}/${builtins.toString prefixLength}";
      };
    };
  };

  ssh = {
    listenPort = 22;
    listenAddresses = [ ];
    listenWildcardIPv4 = "0.0.0.0";
    listenWildcardIPv6 = "[::]";
  };
};
```

### 3.2 Existing yifuwuqi block updates

```diff
 # yifuwuqi.network.lan
-  host = "192.168.0.42";
+  host = "10.42.0.2";
-  gateway = "192.168.0.1";
+  gateway = "10.42.0.1";

 # yifuwuqi.network.sinkhole
-  ipv4.host = "192.168.0.24";
+  ipv4.host = "10.42.0.24";

 # yifuwuqi.dns.systemNameservers
-  [ "::1" "127.0.0.1" "9.9.9.9" ]
+  [ "10.42.0.1" ]
```

---

## 4. Files to Modify

| File | Changes | Issue ref |
|---|---|---|
| `modules/addresses.nix` | Update yifuwuqi LAN IP/gateway/sinkhole/nameservers; add yirukou | A1-A4 |
| `modules/services/adguardhome.nix` | B1 fix; add conditional TLS (skip on yirukou) | B1, E2 |
| `modules/services/tailscale.nix` | Add per-host options for routes/exit-node/mode | D1, D2, D4 |
| `modules/networking/firewall.nix` | Add 10.42.0.1 to container allow; remove 53/853; remove nat block | F3-F5, K1 |
| `modules/networking/interfaces/eno1.nix` | Remove ManageForeignRoutes, keepalived comments, MTU 1492 | C2-C4 |
| `hosts/yifuwuqi/networking.nix` | Remove gateway-failover.nix import | C1 |
| `hosts/yifuwuqi/services.nix` | AdGuardHome import removed; Tailscale to client | D3, E4 |
| `hosts/yifuwuqi/configuration.nix` | Possibly remove adguardhome-related sops secrets (verify) | — |
| `hosts/yitaishi/networking.nix` | Update commented-out WireGuard endpoint IP | B2 |
| `flake.nix` | Add yirukou configuration | H1 |

---

## 5. Migration Phases

### Phase 1 — Code Changes (no network disruption)

All changes in this phase are Nix changes that can be `nixos-rebuild` tested
individually on the affected hosts.

| Step | Action | Files |
|---|---|---|
| 1.1 | Add yirukou address block | `modules/addresses.nix` |
| 1.2 | Update yifuwuqi addresses | `modules/addresses.nix` |
| 1.3 | Refactor tailscale module (add per-host options) | `modules/services/tailscale.nix` |
| 1.4 | Fix hardcoded 192.168.0.42 in adguardhome | `modules/services/adguardhome.nix` |
| 1.5 | Clean up eno1.nix (ManageForeignRoutes, MTU, comments) | `modules/networking/interfaces/eno1.nix` |
| 1.6 | Remove gateway-failover.nix from yifuwuqi | `hosts/yifuwuqi/networking.nix` |
| 1.7 | Update yifuwuqi Tailscale to client mode | `hosts/yifuwuqui/services.nix` |
| 1.8 | Remove AdGuardHome import from yifuwuqi | `hosts/yifuwuqui/services.nix` |
| 1.9 | Update firewall.nix container isolation (add 10.42.0.1, remove 53/853, clean nat) | `modules/networking/firewall.nix` |
| 1.10 | Create hosts/yirukou/addresses.nix | New file |
| 1.11 | Create hosts/yirukou/configuration.nix | New file |
| 1.12 | Create hosts/yirukou/hardware.nix | New file |
| 1.13 | Create hosts/yirukou/boot.nix | New file |
| 1.14 | Create hosts/yirukou/networking.nix | New file |
| 1.15 | Create hosts/yirukou/services.nix | New file |
| 1.16 | Add yirukou to flake.nix | `flake.nix` |
| 1.17 | Rebuild yifuwuqi with new code (pre-migration). Verify it still works on old subnet. | — |

### Phase 2 — Bootstrap Yirukou

| Step | Action |
|---|---|
| 2.1 | Install NixOS on yirukou (live USB → partitioned → nixos-install with initial flake) |
| 2.2 | First boot. Manually set up sops age key. |
| 2.3 | Connect wan0 to ISP router; verify DHCP lease on wan0 |
| 2.4 | `ping 1.1.1.1` — verify WAN Internet |
| 2.5 | `nft list ruleset` — verify NAT + firewall rules load |
| 2.6 | Connect a test laptop to lan0. Verify: |
|     - Gets 10.42.0.50+ via DHCP |
|     - Gateway = 10.42.0.1 |
|     - DNS = 10.42.0.1 (AdGuardHome) |
|     - Internet access via NAT |
|     - SSH to yirukou from laptop works |

### Phase 3 — Yifuwuqi Cutover

| Step | Action |
|---|---|
| 3.1 | Back up yifuwuqi config (`nixos-rebuild switch` on current pre-migration config works, but double-check) |
| 3.2 | Rebuild yifuwuqi with the updated addresses (10.42.0.2, new sinkhole 10.42.0.24) |
| 3.3 | Power down yifuwuqi |
| 3.4 | Disconnect yifuwuqi from old ER706W LAN |
| 3.5 | Connect yifuwuqi eno1 to yirukou lan0 |
| 3.6 | Power up yifuwuqi |
| 3.7 | Verify yifuwuqi gets 10.42.0.2 via static config |
| 3.8 | `ping 10.42.0.1` (yirukou gateway) — verify LAN reachability |
| 3.9 | `ping 1.1.1.1` — verify WAN via yirukou NAT |
| 3.10 | Verify Tailscale is connected (now as client) |
| 3.11 | Verify all services accessible: nginx proxy, WebDAV, MariaDB, Samba, etc. |

### Phase 4 — ER706W → AP Trunk

| Step | Action |
|---|---|
| 4.1 | Back up ER706W current config |
| 4.2 | Factory reset ER706W |
| 4.3 | Direct laptop to ER706W LAN port; initial setup: |
|     - IP: 10.42.0.254/24 |
|     - Gateway: 10.42.0.1 |
|     - DNS: 10.42.0.1 |
|     - DHCP server: disabled |
|     - DHCP relay: disabled |
|     - WAN type: Dynamic IP, WAN port unplugged |
| 4.4 | Create SSID `homelab` (untagged), WPA3, no WPS |
| 4.5 | *(T1a staging: stop here; test WiFi before adding VLANs)* |
| 4.6 | Connect ER706W LAN port to yirukou lan3 |
| 4.7 | Connect phone to `homelab`: verify 10.42.0.x, gateway 10.42.0.1, Internet works |
| 4.8 | Add SSID `iot` (VLAN 20), `guest` (VLAN 30) |
| 4.9 | Rebuild yirukou with VLAN config in networking.nix |
| 4.10 | Test per-SSID isolation (see §6) |

### Phase 5 — Tailscale Cutover

| Step | Action |
|---|---|
| 5.1 | Verify yirukou Tailscale is subnet router advertising 10.42.0.0/24 |
| 5.2 | Verify yifuwuqi Tailscale is now client only (no exit-node, no route) |
| 5.3 | From Tailscale remote client: `ping 10.42.0.2` (yifuwuqi) |
| 5.4 | From Tailscale remote client: `ping 10.42.0.1` (yirukou) |
| 5.5 | Verify Tailscale MagicDNS still resolves hostnames |

### Phase 6 — Cleanup

| Step | Action |
|---|---|
| 6.1 | Yitaishi + yixiaoqing: connect network cables to yirukou lan1/lan2 (or keep on ER706W homelab SSID) |
| 6.2 | Renew DHCP leases on all clients |
| 6.3 | Update commented-out WireGuard endpoint IPs in yitaishi networking.nix |
| 6.4 | Remove old ER706W from upstream router path (if applicable) |
| 6.5 | Document new topology in repo README |

---

## 6. Testing Plan

### 6.1 WAN / Internet

```bash
# On yirukou
ping 1.1.1.1
ping -c 2 google.com
curl -I https://example.com
nslookup google.com 10.42.0.1
```

### 6.2 NAT

```bash
# From a client on 10.42.0.x, 10.42.20.x, 10.42.30.x
curl -s ifconfig.me   # should show ISP public IP
```

### 6.3 VLAN Isolation

```bash
# On yirukou, verify counters:
nft list chain inet yirukou forward

# From IoT client (10.42.20.x):
ping 10.42.0.1      # FAIL (ICMP blocked on input)
ping 10.42.0.2      # FAIL (forward drop)
curl http://10.42.0.2:80  # FAIL (forward drop)
curl https://1.1.1.1      # OK (Internet egress)

# From Guest client (10.42.30.x):
ping 10.42.20.1     # FAIL (no cross-VLAN forward rule)
ping 10.42.0.1      # FAIL (ICMP blocked on input)

# From Trusted LAN (10.42.0.x):
ping 10.42.20.1     # OK (trusted can initiate to IoT)
```

### 6.4 DHCP

```bash
# Connect fresh client to each VLAN:
# - Gets IP in correct scope
# - Gateway = respective VLAN gateway
# - DNS = 10.42.0.1, 10.42.20.1, 10.42.30.1
systemd-resolve --status  # or check /etc/resolv.conf
```

### 6.5 Services

```bash
# From trusted LAN:
curl https://adguard.fufu.land    # AdGuard UI → OK
curl https://search.fufu.land     # SearXNG → OK
curl https://agent.fufu.land      # Opencode → OK
curl https://netdata.fufu.land    # Netdata → OK
curl https://prtnr.fufu.land      # Portainer → OK
curl https://webdav.fufu.land     # WebDAV → OK

# Samba mount from yitaishi/yixiaoqing:
ls /mnt/samba/share/      # OK
```

### 6.6 Tailscale

```bash
# From Tailscale remote client:
tailscale ping 100.69.0.2      # yirukou
tailscale ping 100.69.0.1      # yifuwuqi
ping 10.42.0.2                 # via subnet routes
```

### 6.7 Firewall Hardening

```bash
# From Internet-facing wan0 (simulate external scan):
nmap -sS -p 22,80,443,53,853 $PUBLIC_IP  # Should show filtered/dropped

# Verify no log spam from Internet noise:
journalctl -k --since "5 minutes ago" | grep yirukou-input
# Should show zero or very few entries from wan0
```

---

## 7. Rollback Plan

### Full Rollback (back to ER706W router + 192.168.0.0/24)

```text
1. Unplug yirukou from the network entirely.
2. Restore backed-up ER706W config (or factory reset + reconfig).
3. Reconnect the ER706W LAN as the upstream router (192.168.0.1).
4. Re-enable ER706W DHCP server.
5. Revert yifuwuqi addresses in Nix:
   - 10.42.0.2  → 192.168.0.42
   - gateway 10.42.0.1 → 192.168.0.1
   - sinkhole 10.42.0.24 → 192.168.0.24
   - nameservers → ["127.0.0.1" "9.9.9.9"]
6. Revert yifuwuqi services: re-add AdGuardHome, set Tailscale back to server.
7. Revert firewall.nix: re-add 53/853, remove 10.42.0.1 container allow.
8. Rebuild yifuwuqi.
9. Reconnect yifuwuqi eno1 to ER706W LAN.
10. Revert flake.nix (remove yirukou entry) — or keep it but don't deploy to yirukou.
```

### Partial Rollback (keep yirukou, drop VLANs)

```text
1. Remove VLAN config from yirukou networking.nix.
2. Set ER706W to single untagged SSID (homelab only).
3. All clients land on 10.42.0.0/24.
4. nftables → remove VLAN isolation rules, keep NAT + basic firewall.
5. Rebuild yirukou.
```
