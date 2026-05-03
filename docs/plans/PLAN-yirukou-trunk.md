# yirukou Trunk — T1 Implementation Spec

## 1. Topology

```
ISP router              ISP2 router
192.168.1.1             192.168.1.1
    |                         |
    | 192.168.1.0/24 (DHCP)   | 192.168.1.0/24 (DHCP, clash)
    |                         |
  wan0                      wan1
           \              /
               yirukou
                 |
                 +-- br0 (10.42.0.1/24)
                 |     members: lan0, lan1, lan2, lan3
                 |       lan0 → yifuwuqi (10.42.0.2)
                 |       lan1 → DHCP (yitaishi, etc.)
                 |       lan2 → DHCP (yixiaoqing, etc.)
                 |       lan3 → trunk to ER706W (untagged = ER706W mgmt + homelab SSID)
                 |
                 +-- lan3.20 (10.42.20.1/24) — VLAN 20, iot gateway
                 +-- lan3.30 (10.42.30.1/24) — VLAN 30, guest gateway
                 +-- tailscale0 (100.69.0.2/32) — subnet router for 10.42.0.0/24
```

This spec implements T1: yirukou as router plus ER706W as an AP-like VLAN trunk. The best long-term WiFi endpoint is still T6: the same yirukou design with a purpose-built VLAN-aware AP instead of the ER706W. Use T1a first if you want a safer cutover: untagged trusted LAN/WiFi only, then add VLANs after the router path is proven.

**Subnets and DHCP:**

| VLAN | Interface | Subnet | Gateway | DHCP scope |
|---|---|---|---|---|
| *untagged* | `br0` | `10.42.0.0/24` | `10.42.0.1` | `10.42.0.50 - 10.42.0.200` |
| 20 | `lan3.20` | `10.42.20.0/24` | `10.42.20.1` | `10.42.20.50 - 10.42.20.200` |
| 30 | `lan3.30` | `10.42.30.0/24` | `10.42.30.1` | `10.42.30.50 - 10.42.30.200` |

Static reservations (on `br0` scope):

| Host | IP |
|---|---|
| yifuwuqi | `10.42.0.2` |
| ER706W | `10.42.0.254` |

**ER706W SSID to VLAN mapping:**

| SSID | VLAN | Client subnet |
|---|---|---|
| `homelab` | untagged (native) | `10.42.0.0/24` |
| `iot` | 20 | `10.42.20.0/24` |
| `guest` | 30 | `10.42.30.0/24` |

## 2. systemd-networkd — yirukou NixOS Config

### 2.1 Netdevs

#### Bridge `br0`

```nix
systemd.network.netdevs."10-br0" = {
  netdevConfig = {
    Kind = "bridge";
    Name = "br0";
  };
};
```

#### VLAN netdevs on `lan3`

```nix
systemd.network.netdevs."20-lan3.20" = {
  netdevConfig = {
    Kind = "vlan";
    Name = "lan3.20";
  };
  vlanConfig.Id = 20;
};

systemd.network.netdevs."20-lan3.30" = {
  netdevConfig = {
    Kind = "vlan";
    Name = "lan3.30";
  };
  vlanConfig.Id = 30;
};
```

### 2.2 Networks

#### WAN — `wan0`

```nix
systemd.network.networks."10-wan0" = {
  matchConfig.Name = "wan0";
  networkConfig = {
    DHCP = "yes";
    IPv6AcceptRA = "no";
  };
  dhcpV4Config.UseDNS = false;
  dhcpV4Config.RouteMetric = 100;
  linkConfig.RequiredForOnline = "carrier";
};
```

#### WAN spare — `wan1` (clash documented, not activated)

```nix
# wan1 is connected to ISP2 modem at 192.168.1.1.
# Subnet clash with wan0 (both 192.168.1.0/24).
# Activating this requires VRF, netns, or ISP modem reconfig.
# For now: DHCP enabled but isolated by manual intervention or
# by not bringing the interface up automatically.
systemd.network.networks."10-wan1" = {
  matchConfig.Name = "wan1";
  networkConfig = {
    DHCP = "yes";
    IPv6AcceptRA = "no";
  };
  dhcpV4Config.UseDNS = false;
  dhcpV4Config.RouteMetric = 200;
  linkConfig.RequiredForOnline = "no";
};
```

#### Bridge member ports — `lan0`, `lan1`, `lan2`

```nix
for each in [ "lan0" "lan1" "lan2" ]:
systemd.network.networks."20-${each}" = {
  matchConfig.Name = each;
  networkConfig.Bridge = "br0";
  linkConfig.RequiredForOnline = "no";
};
```

#### Trunk port — `lan3` (bridge member, VLAN netdevs peek at raw device)

```nix
systemd.network.networks."20-lan3" = {
  matchConfig.Name = "lan3";
  networkConfig = {
    Bridge = "br0";
    VLAN = [ "lan3.20" "lan3.30" ];
  };
  # Untagged frames pass through to br0 normally.
  # Tagged frames are delivered to the explicitly attached VLAN netdevs.
  # Do not let an unplugged AP/trunk block boot or network-online during staging.
  linkConfig.RequiredForOnline = "no";
};
```

#### Bridge interface — `br0`

```nix
systemd.network.networks."30-br0" = {
  matchConfig.Name = "br0";
  address = [ addresses.network.lan.ipv4.address ];
  networkConfig = {
    DHCP = "no";
    IPv6AcceptRA = "no";
    LinkLocalAddressing = "no";
    IPForward = "yes";
    DHCPServer = "yes";
    IPMasquerade = "no";  # NAT handled by nftables
  };
  # WAN should gate Internet readiness; LAN ports should not block boot.
  linkConfig.RequiredForOnline = "no";
};
```

#### VLAN subinterfaces — `lan3.20`, `lan3.30`

```nix
systemd.network.networks."40-lan3.20" = {
  matchConfig.Name = "lan3.20";
  address = [ addresses.network.vlans.iot.ipv4.address ];
  networkConfig = {
    DHCP = "no";
    IPv6AcceptRA = "no";
    IPForward = "yes";
    DHCPServer = "yes";
  };
};

systemd.network.networks."40-lan3.30" = {
  matchConfig.Name = "lan3.30";
  address = [ addresses.network.vlans.guest.ipv4.address ];
  networkConfig = {
    DHCP = "no";
    IPv6AcceptRA = "no";
    IPForward = "yes";
    DHCPServer = "yes";
  };
};
```

### 2.3 Full networking.nix sketch

```nix
# hosts/yirukou/networking.nix
{ addresses, ... }:

let
  inherit (addresses.network) lan vlans;

  mkBridgeMember = name: {
    "20-${name}" = {
      matchConfig.Name = name;
      networkConfig.Bridge = lan.interface;
      linkConfig.RequiredForOnline = "no";
    };
  };

  mkVlan = vlan: {
    "20-${vlan.interface}" = {
      netdevConfig = {
        Kind = "vlan";
        Name = vlan.interface;
      };
      vlanConfig.Id = vlan.id;
    };
  };

  mkVlanNetwork = vlan: {
    "40-${vlan.interface}" = {
      matchConfig.Name = vlan.interface;
      address = [ vlan.ipv4.address ];
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = "no";
        IPForward = "yes";
        DHCPServer = "yes";
      };
    };
  };
in
{
  networking = {
    useNetworkd = true;
    useDHCP = false;
    networkmanager.enable = false;
    firewall.enable = false;  # replaced by nftables below
    nftables.enable = true;

    nftables.tables = {
      # (see section 3)
    };
  };

  systemd.network = {
    netdevs = {
      "10-br0" = {
        netdevConfig = {
          Kind = "bridge";
          Name = lan.interface;
        };
      };
    } // (mkVlan vlans.iot) // (mkVlan vlans.guest);

    networks = {
      "10-wan0" = {
        matchConfig.Name = addresses.network.wan.interface;
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "no";
        };
        dhcpV4Config = {
          UseDNS = false;
          RouteMetric = 100;
        };
        linkConfig.RequiredForOnline = "carrier";
      };
      # WAN spare (clash with wan0, not currently activated — see note above)
      "10-wan1" = {
        matchConfig.Name = addresses.network.wanSpare.interface;
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = "no";
        };
        dhcpV4Config = {
          UseDNS = false;
          RouteMetric = 200;
        };
        linkConfig.RequiredForOnline = "no";
      };
    }
    // (mkBridgeMember "lan0")
    // (mkBridgeMember "lan1")
    // (mkBridgeMember "lan2")
    // {
      "20-${addresses.network.trunk.interface}" = {
        matchConfig.Name = addresses.network.trunk.interface;
        networkConfig = {
          Bridge = lan.interface;
          VLAN = [
            vlans.iot.interface
            vlans.guest.interface
          ];
        };
        linkConfig.RequiredForOnline = "no";
      };
      "30-${lan.interface}" = {
        matchConfig.Name = lan.interface;
        address = [ lan.ipv4.address ];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "no";
          IPForward = "yes";
          DHCPServer = "yes";
        };
        linkConfig.RequiredForOnline = "no";
      };
    }
    // (mkVlanNetwork vlans.iot)
    // (mkVlanNetwork vlans.guest);
  };

  services.resolved.enable = false;
}
```

## 3. nftables — Firewall + NAT

### Requirements

1. NAT (masquerade) all LAN subnet traffic to `wan0`
2. `10.42.0.0/24` (trusted LAN) → full Internet access, can initiate to any local subnet
3. `10.42.20.0/24` (iot) → Internet only, **no** access to `10.42.0.0/24` or `10.42.30.0/24`
4. `10.42.30.0/24` (guest) → Internet only, **no** access to `10.42.0.0/24` or `10.42.20.0/24`
5. Allow DHCP+DNS from all subnets to yirukou
6. Allow SSH/admin access only from trusted LAN and Tailscale
7. Allow ICMP/ping to yirukou only from trusted LAN and Tailscale
8. Allow Tailscale traffic
9. Allow established/related return traffic

### 3.1 Complete nftables ruleset

```nix
networking.nftables.tables.yirukou = {
  family = "inet";
  content = let
    trusted  = "10.42.0.0/24";
    iot      = "10.42.20.0/24";
    guest    = "10.42.30.0/24";
    br0      = addresses.network.lan.interface;
    trunk    = addresses.network.trunk.interface;
    wan      = addresses.network.wan.interface;
    iotIf    = addresses.network.vlans.iot.interface;
    guestIf  = addresses.network.vlans.guest.interface;
    tsIf     = addresses.network.tailscale.interface;
    wanIfs   = "{ ${wan}, ${addresses.network.wanSpare.interface} }";
    allLANs  = "{ ${trusted}, ${iot}, ${guest} }";
    lanIfs   = "{ ${br0}, ${iotIf}, ${guestIf} }";
  in ''
    # ── NAT ────────────────────────────────────────────────
    chain postrouting {
      type nat hook postrouting priority srcnat; policy accept;
      ip saddr ${allLANs} oifname ${wanIfs} masquerade
    }

    # ── FORWARD (inter-VLAN isolation) ─────────────────────
    chain forward {
      type filter hook forward priority filter; policy drop;

      # Allow outbound from all LAN subnets to Internet
      iifname ${lanIfs} oifname ${wanIfs} accept
      iifname ${wanIfs} oifname ${lanIfs} ct state established,related accept

      # Trusted LAN ↔ Trusted LAN (same br0, no routing needed,
      # but forward hook still sees our routed traffic)
      iifname ${br0} oifname ${br0} accept

      # Trusted LAN can initiate to IoT and Guest
      # (e.g. ping IoT devices, help guest users)
      iifname ${br0} oifname ${iotIf} accept
      iifname ${br0} oifname ${guestIf} accept
      iifname ${iotIf} oifname ${br0} ct state established,related accept
      iifname ${guestIf} oifname ${br0} ct state established,related accept

      # IoT → IoT (same VLAN) and Guest → Guest (same VLAN) via established
      iifname ${iotIf} oifname ${iotIf} accept
      iifname ${guestIf} oifname ${guestIf} accept

      # IoT → Internet only (already handled by wan accept above)
      # IoT ↛ Guest  (implicit drop by policy)
      # Guest → Internet only (already handled)
      # Guest ↛ IoT (implicit drop by policy)

      # Tailscale
      iifname ${tsIf} oifname ${lanIfs} accept
      iifname ${lanIfs} oifname ${tsIf} accept

      # Log drops for debugging
      counter drop
    }

    # ── INPUT (to yirukou itself) ──────────────────────────
    chain input {
      type filter hook input priority filter; policy drop;

      # Loopback
      iifname lo accept

      # Established/related
      ct state established,related accept

      # ICMP from trusted LAN only. Tailscale is accepted below.
      iifname ${br0} ip protocol icmp accept
      iifname ${br0} ip6 nexthdr ipv6-icmp accept

      # SSH from trusted LAN only. Tailscale is accepted below.
      iifname ${br0} tcp dport 22 accept

      # DHCP from all LAN subnets
      iifname ${lanIfs} udp dport { 67, 68 } accept

      # DNS from all LAN subnets (AdGuardHome on 53)
      iifname ${lanIfs} tcp dport 53 accept
      iifname ${lanIfs} udp dport 53 accept

      # DNS-over-TLS (853) from trusted LAN only
      iifname ${br0} tcp dport 853 accept
      iifname ${br0} udp dport 853 accept

      # AdGuard web UI / local encrypted DNS from trusted LAN only
      iifname ${br0} tcp dport { 3333, 3443, 853 } accept
      iifname ${br0} udp dport 853 accept

      # Tailscale
      iifname ${tsIf} accept

      log prefix "yirukou-input-drop: " counter drop
    }
  '';
};
```

### 3.2 Why this works

- `policy drop` on FORWARD means any inter-VLAN traffic that isn't explicitly allowed is dropped.
- IoT (`10.42.20.0/24`) can reach the Internet (accepted by `iifname {lanIfs} oifname wan`) and yirukou DHCP/DNS, but has no rule allowing it to reach `10.42.0.0/24`, `10.42.30.0/24`, or yirukou admin services — implicit drop.
- Guest (`10.42.30.0/24`) same story — Internet only.
- Trusted LAN can initiate to IoT/Guest (unidirectional accept) but IoT/Guest cannot initiate back except via established/related.
- Each VLAN's broadcast domain is isolated because they're on different L3 interfaces. `br0` carries untagged trusted LAN; `lan3.20` and `lan3.30` are separate routed interfaces.

## 4. AdGuardHome DNS + systemd-networkd DHCP

AdGuardHome should handle DNS/filtering only. systemd-networkd should handle DHCP on `br0`, `lan3.20`, and `lan3.30` because it is already managing the interfaces and supports one DHCP server per interface declaratively.

### 4.1 Rejected alternative: AdGuardHome DHCP per VLAN

This sketch is kept as background only. AdGuardHome's DHCP server is not a good fit for multiple VLAN scopes, so do not use this as the target implementation.

```yaml
# AdGuardHome.yaml (managed via NixOS module or manual config)
dhcp:
  enabled: true
  interface_name: br0
  local_domain_name: lan
  dhcpv4:
    gateway_ip: 10.42.0.1
    subnet_mask: 255.255.255.0
    range_start: 10.42.0.50
    range_end: 10.42.0.200
    lease_duration: 86400

  # Static reservations
  dhcp_static_leases:
    - mac: <yifuwuqi MAC>
      ip: "10.42.0.2"
    - mac: <ER706W MAC>
      ip: "10.42.0.254"

# Second DHCP scope for IoT — separate interface
# AdGuardHome calls these "DHCP options per interface"
# In the YAML, multiple scopes are arrays under dhcp[]

# IoT scope
# dhcp:
#   - interface_name: lan3.20
#     dhcpv4:
#       gateway_ip: 10.42.20.1
#       subnet_mask: 255.255.255.0
#       range_start: 10.42.20.50
#       range_end: 10.42.20.200

# Guest scope
#   - interface_name: lan3.30
#     dhcpv4:
#       gateway_ip: 10.42.30.1
#       subnet_mask: 255.255.255.0
#       range_start: 10.42.30.50
#       range_end: 10.42.30.200
```

**Important:** Do not depend on AdGuardHome multi-scope DHCP for this router. If systemd-networkd DHCP is not desired later, alternatives are:

1. **Multiple AdGuardHome instances** — one per VLAN (via Podman containers bound to each VLAN interface)
2. **systemd-networkd DHCP server** — configure `systemd.network.networks` with `[DHCPServer]` sections per interface, with AdGuardHome as DNS
3. **dnsmasq** — run a separate dnsmasq for DHCP on VLAN interfaces, forwarding DNS to AdGuardHome

The **recommended approach** is systemd-networkd DHCP server for simplicity — it's already being used for the rest of the network stack:

```nix
systemd.network.networks."40-lan3.20" = {
  matchConfig.Name = "lan3.20";
  address = [ vlans.iot.ipv4.address ];
  networkConfig = {
    DHCP = "no";
    IPv6AcceptRA = "no";
    IPForward = "yes";
    DHCPServer = "yes";
  };
  dhcpServerConfig = {
    PoolOffset = 50;
    PoolSize = 151;
    EmitDNS = "yes";
    DNS = [ "10.42.20.1" ];  # AdGuardHome on VLAN interface
    EmitRouter = "yes";
  };
};
```

AdGuardHome only needs to listen on each VLAN IP for DNS. It does not need to serve DHCP on any interface.

**Decision:** Use systemd-networkd DHCP server on all interfaces. AdGuardHome handles DNS only. This avoids AdGuardHome multi-scope complexity and keeps DHCP fully declarative in NixOS.

### 4.2 systemd-networkd DHCP with AdGuardHome DNS

Each serving interface needs `networkConfig.DHCPServer = "yes"` plus the matching `dhcpServerConfig`.

```nix
# On br0
systemd.network.networks."30-br0".dhcpServerConfig = {
  PoolOffset = 50;
  PoolSize = 151;
  EmitDNS = "yes";
  DNS = [ "10.42.0.1" ];
  EmitRouter = "yes";
};

# On lan3.20
systemd.network.networks."40-lan3.20".dhcpServerConfig = {
  PoolOffset = 50;
  PoolSize = 151;
  EmitDNS = "yes";
  DNS = [ "10.42.20.1" ];
  EmitRouter = "yes";
};

# On lan3.30
systemd.network.networks."40-lan3.30".dhcpServerConfig = {
  PoolOffset = 50;
  PoolSize = 151;
  EmitDNS = "yes";
  DNS = [ "10.42.30.1" ];
  EmitRouter = "yes";
};
```

AdGuardHome must listen on all three gateway IPs: `10.42.0.1`, `10.42.20.1`, `10.42.30.1` (plus loopback). This means binding to `0.0.0.0` or explicitly listing each IP.

**Static DHCP reservations with systemd-networkd:**

```nix
systemd.network.networks."30-br0".dhcpServerStaticLeases = [
  { dhcpServerStaticLeaseConfig = {
      MACAddress = "<yifuwuqi MAC>";
      Address = "10.42.0.2";
    };
  }
];
```

## 5. ER706W Setup

### 5.1 Per-SSID VLAN tagging

The critical configuration on the ER706W is binding each SSID to a VLAN ID.

**Expected ER706W web UI path:**

1. **Network → LAN**:
   - IP: `10.42.0.254/24`
   - Gateway: `10.42.0.1`
   - DNS: `10.42.0.1`
   - DHCP server: **disabled**
   - DHCP relay: **disabled**

2. **Network → WAN**:
   - Set to "Dynamic IP" but leave WAN port **unplugged**
   - Or set to "Disabled" if option exists

3. **Wireless → Wireless Settings**:
   - SSID 1: `homelab` — VLAN: *(none/untagged)*
   - SSID 2: `iot` — VLAN: 20 (if "VLAN per SSID" is a checkbox or dropdown)
   - SSID 3: `guest` — VLAN: 30

4. **Wireless → Security**:
   - All SSIDs: WPA3-Personal or WPA2/WPA3 mixed
   - WPS: disabled

5. **VPN, NAT, Firewall, Policy Routing**:
   - All disabled / cleared

### 5.2 Physical cabling

```
ER706W LAN port (any of the 4 RJ45 LAN ports) ──→ yirukou lan3
ER706W WAN port ──→ unplugged
```

### 5.3 ER706W caveats in trunk mode

- The ER706W must support per-SSID VLAN tagging in its AP-like configuration (no WAN). The spec sheet lists "Wireless VLAN per SSID" — verify in the actual web UI after factory reset.
- The ER706W management interface (web UI) is on `10.42.0.254` via untagged LAN.
- The ER706W itself may not have Internet access (no WAN route). This may break NTP, Omada Cloud, and online firmware checks. Acceptable for day one; replace with a real AP later if annoying.

## 6. Tailscale

### 6.1 yirukou as subnet router

```nix
# modules/services/tailscale.nix — update for yirukou
services.tailscale = {
  enable = true;
  useRoutingFeatures = "server";  # exit node + subnet router
  # Advertise the trusted LAN route
  extraUpFlags = [ "--advertise-routes=10.42.0.0/24" ];
};
```

Do NOT advertise `10.42.20.0/24` or `10.42.30.0/24` — these are untrusted VLANs.

### 6.2 Changes to existing tailscale.nix

In `modules/services/tailscale.nix`, the `--exit-node` and `--advertise-routes` flags need to become per-host. Currently they're hardcoded to reference yifuwuqi. Options:

**Option A: Make routing modes configurable via module options**

```nix
# Add to modules/services/tailscale.nix
{ config, lib, allAddresses, ... }:
let
  cfg = config.services.tailscale;
  hostCfg = config.yirukou or {};
in
{
  options.yirukou.tailscale = {
    exitNodeHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "10.42.0.0/24" ];
    };
    routingMode = lib.mkOption {
      type = lib.types.enum [ "client" "server" "both" ];
      default = "server";
    };
  };
}
```

**Option B: Per-host tailscale module imports**

Create `modules/services/tailscale-yirukou.nix` instead of modifying the existing module.

**Decision:** Prefer Option A. Make the existing Tailscale module configurable per host so yirukou can advertise `10.42.0.0/24` while yifuwuqi becomes a normal client or optional secondary route/exit node. Option B is acceptable only as a short bootstrap shortcut.

## 7. Files to Create/Modify

### 7.1 New files

```
hosts/yirukou/
  configuration.nix     — main entry, imports the rest
  hardware.nix          — lan* + wan* NIC names (from lspci/nixos-generate-config)
  networking.nix        — systemd-networkd + nftables (this plan)
  services.nix          — AdGuardHome, Tailscale, SSH, Netdata
  addresses.nix         — _module.args.addresses = allAddresses.hosts.yirukou
  boot.nix              — kernel params, bootloader
```

Optional bootstrap shortcut only: `modules/services/tailscale-yirukou.nix`. Prefer the configurable shared Tailscale module instead.

### 7.2 Modified files

| File | Change |
|---|---|
| `modules/addresses.nix` | Add `yirukou` entry (see PLAN-yirukou.md §15) |
| `flake.nix` | Add `yirukou` NixOS configuration |
| `hosts/yifuwuqi/networking.nix` | Remove `gateway-failover.nix` import; update LAN to `10.42.0.2/24` |
| `hosts/yifuwuqi/services.nix` | Swap Tailscale to client-only unless keeping it as secondary route/exit node |
| `modules/services/tailscale.nix` | Add per-host route advertisement and exit-node options |
| `modules/services/adguardhome.nix` | Prefer DNS on yirukou; keep service rewrites pointing to yifuwuqi `10.42.0.2` unless reverse proxy moves |
| `modules/networking/firewall.nix` | Add `10.42.0.0/24` to container isolation allow list |

## 8. Testing Plan

### 8.1 Boot yirukou standalone (before network cutover)

1. Install NixOS on yirukou with the config above.
2. Connect `wan0` to ISP router LAN port. Verify DHCP lease.
3. Verify `ping 1.1.1.1` works.
4. Connect a laptop to `lan0`. Verify:
   - Gets IP `10.42.0.50+` via DHCP
   - Gateway is `10.42.0.1`
   - DNS is `10.42.0.1` (AdGuardHome)
   - Internet works
5. SSH to `10.42.0.1`.

### 8.2 VLAN testing (with ER706W)

1. Connect ER706W LAN port to `lan3`.
2. On ER706W: create SSID `homelab` (untagged), `iot` (VLAN 20), `guest` (VLAN 30).
3. Connect phone to `homelab`:
   - IP: `10.42.0.51+`
   - Gateway: `10.42.0.1`
   - Internet works
    - Can reach yifuwuqi (once migrated) at `10.42.0.2`
4. Connect phone to `iot`:
    - IP: `10.42.20.50+`
    - Gateway: `10.42.20.1`
    - Internet works
    - Cannot `ping 10.42.0.1` or `ping 10.42.0.2`

- `nslookup google.com 10.42.20.1` works (DNS)

5. Connect phone to `guest`:
   - IP: `10.42.30.50+`
   - Gateway: `10.42.30.1`
   - Internet works
   - Can use its gateway only for DHCP/DNS; cannot ping/admin yirukou or reach other `10.42.x.x` addresses

### 8.3 VLAN isolation verification

```bash
# From yirukou, monitor drops:
nft list ruleset | grep counter
nft list chain inet yirukou forward
```

From IoT device, try:

```bash
ping 10.42.0.1      # should FAIL (no echo reply if ICMP blocked on input, or forward drop)
ping 10.42.30.1     # should FAIL
curl http://10.42.0.2:80  # should FAIL (forward drop)
```

From guest device, same tests against `10.42.0.x` and `10.42.20.x`.

The `counter drop` in the FORWARD chain will increment for each blocked attempt — verify with:

```bash
nft list chain inet yirukou forward
```

## 9. Migration Order Summary

1. yirukou hardware setup + NixOS install
2. yirukou `wan0` → ISP router, verify Internet
3. yirukou DHCP + DNS + NAT + firewall operational
4. Verify wired client on `lan0` gets `10.42.0.x`
5. Optional T1a: configure ER706W as untagged trusted WiFi only and verify basic wireless
6. ER706W factory reset or reconfigure, configure trunk SSIDs, connect to `lan3`
7. Verify WiFi per SSID works + VLAN isolation
8. Move yifuwuqi to `10.42.0.2`, reconnect to br0 port (lan0)
9. Update Tailscale route on yirukou; update AdGuard rewrites while keeping service records on yifuwuqi
10. Move other wired clients to br0 ports
11. Validate all services

Rollback:

1. Restore the ER706W backup and reconnect the old LAN.
2. Restore yifuwuqi to `192.168.0.42/24` with gateway `192.168.0.1`.
3. Re-enable ER706W DHCP.
4. Disconnect or disable yirukou DHCP/NAT until fixed.
