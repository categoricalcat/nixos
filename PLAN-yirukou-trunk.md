# yirukou Trunk — T1 Implementation Spec

## 1. Topology

```
ISP router
192.168.1.1
    |
    | 192.168.1.0/24 (DHCP)
    |
  wan0
yirukou
    |
    +-- br0 (10.42.0.1/24)
    |     members: lan0, lan1, lan2, lan3
    |       lan0 → yifuwuqi (10.42.0.42)
    |       lan1 → yitaishi (10.42.0.43)
    |       lan2 → yixiaoqing (10.42.0.44)
    |       lan3 → trunk to ER706W (untagged = ER706W mgmt + homelab SSID)
    |
    +-- lan3.20 (10.42.20.1/24) — VLAN 20, iot gateway
    +-- lan3.30 (10.42.30.1/24) — VLAN 30, guest gateway
    +-- tailscale0 (100.69.0.2/32) — subnet router for 10.42.0.0/24
```

**Subnets and DHCP:**

| VLAN | Interface | Subnet | Gateway | DHCP scope |
|---|---|---|---|---|
| *untagged* | `br0` | `10.42.0.0/24` | `10.42.0.1` | `10.42.0.50 - 10.42.0.200` |
| 20 | `lan3.20` | `10.42.20.0/24` | `10.42.20.1` | `10.42.20.50 - 10.42.20.200` |
| 30 | `lan3.30` | `10.42.30.0/24` | `10.42.30.1` | `10.42.30.50 - 10.42.30.200` |

Static reservations (on `br0` scope):

| Host | IP |
|---|---|
| yifuwuqi | `10.42.0.42` |
| yitaishi | `10.42.0.43` |
| yixiaoqing | `10.42.0.44` |
| ER706W | `10.42.0.2` |

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
  networkConfig.Bridge = "br0";
  # VLAN netdevs lan3.20 and lan3.30 are stacked on the raw lan3 device.
  # They intercept tagged frames before the bridge sees them.
  # Untagged frames pass through to br0 normally.
  linkConfig.RequiredForOnline = "carrier";
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
    IPMasquerade = "no";  # NAT handled by nftables
  };
  linkConfig.RequiredForOnline = "carrier";
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
  };
};

systemd.network.networks."40-lan3.30" = {
  matchConfig.Name = "lan3.30";
  address = [ addresses.network.vlans.guest.ipv4.address ];
  networkConfig = {
    DHCP = "no";
    IPv6AcceptRA = "no";
    IPForward = "yes";
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
    }
    // (mkBridgeMember "lan0")
    // (mkBridgeMember "lan1")
    // (mkBridgeMember "lan2")
    // {
      "20-${addresses.network.trunk.interface}" = {
        matchConfig.Name = addresses.network.trunk.interface;
        networkConfig.Bridge = lan.interface;
        linkConfig.RequiredForOnline = "carrier";
      };
      "30-${lan.interface}" = {
        matchConfig.Name = lan.interface;
        address = [ lan.ipv4.address ];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = "no";
          LinkLocalAddressing = "no";
          IPForward = "yes";
        };
        linkConfig.RequiredForOnline = "carrier";
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
5. Allow SSH from all LAN+IoT+Guest to yirukou itself
6. Allow DHCP+DNS from all subnets to yirukou
7. Allow Tailscale traffic
8. Allow established/related return traffic

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
    allLANs  = "{ ${trusted}, ${iot}, ${guest} }";
    lanIfs   = "{ ${br0}, ${iotIf}, ${guestIf} }";
  in ''
    # ── NAT ────────────────────────────────────────────────
    chain postrouting {
      type nat hook postrouting priority srcnat; policy accept;
      oifname ${wan} masquerade
    }

    # ── FORWARD (inter-VLAN isolation) ─────────────────────
    chain forward {
      type filter hook forward priority filter; policy drop;

      # Allow outbound from all LAN subnets to Internet
      iifname ${lanIfs} oifname ${wan} accept
      iifname ${wan} oifname ${lanIfs} ct state established,related accept

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

      # ICMP from anywhere
      ip protocol icmp accept
      ip6 nexthdr ipv6-icmp accept

      # SSH from all LAN subnets
      iifname ${lanIfs} tcp dport 22 accept

      # DHCP from all LAN subnets
      iifname ${lanIfs} udp dport { 67, 68 } accept

      # DNS from all LAN subnets (AdGuardHome on 53)
      iifname ${lanIfs} tcp dport 53 accept
      iifname ${lanIfs} udp dport 53 accept

      # DNS-over-TLS (853) from trusted LAN only
      iifname ${br0} tcp dport 853 accept
      iifname ${br0} udp dport 853 accept

      # HTTP/HTTPS (AdGuard web UI 3000/3443) from trusted LAN only
      iifname ${br0} tcp dport { 80, 443, 3000 } accept

      # Tailscale
      iifname ${tsIf} accept

      log prefix "yirukou-input-drop: " counter drop
    }
  '';
};
```

### 3.2 Why this works

- `policy drop` on FORWARD means any inter-VLAN traffic that isn't explicitly allowed is dropped.
- IoT (`10.42.20.0/24`) can reach the Internet (accepted by `iifname {lanIfs} oifname wan`) but has no rule allowing it to reach `10.42.0.0/24` or `10.42.30.0/24` — implicit drop.
- Guest (`10.42.30.0/24`) same story — Internet only.
- Trusted LAN can initiate to IoT/Guest (unidirectional accept) but IoT/Guest cannot initiate back except via established/related.
- Each VLAN's broadcast domain is isolated because they're on different L3 interfaces. `br0` carries untagged trusted LAN; `lan3.20` and `lan3.30` are separate routed interfaces.

## 4. AdGuardHome — DHCP per VLAN

AdGuardHome must serve DHCP on multiple interfaces with different scopes.

### 4.1 Configuration sketch

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
      ip: "10.42.0.42"
    - mac: <yitaishi MAC>
      ip: "10.42.0.43"
    - mac: <yixiaoqing MAC>
      ip: "10.42.0.44"
    - mac: <ER706W MAC>
      ip: "10.42.0.2"

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

**Important:** AdGuardHome's multi-scope DHCP support needs verification. If AdGuardHome cannot serve DHCP on multiple interfaces with different scopes, alternatives:

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

AdGuardHome only needs to listen on each VLAN IP for DNS. It also needs to be serving DHCP on `br0`, or systemd-networkd can serve DHCP on `br0` too.

**Decision:** Use systemd-networkd DHCP server on all interfaces. AdGuardHome handles DNS only. This avoids AdGuardHome multi-scope complexity and keeps DHCP fully declarative in NixOS.

### 4.2 systemd-networkd DHCP with AdGuardHome DNS

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
      Address = "10.42.0.42";
    };
  }
  { dhcpServerStaticLeaseConfig = {
      MACAddress = "<yitaishi MAC>";
      Address = "10.42.0.43";
    };
  }
  { dhcpServerStaticLeaseConfig = {
      MACAddress = "<yixiaoqing MAC>";
      Address = "10.42.0.44";
    };
  }
];
```

## 5. ER706W Setup

### 5.1 Per-SSID VLAN tagging

The critical configuration on the ER706W is binding each SSID to a VLAN ID.

**Expected ER706W web UI path:**

1. **Network → LAN**:
   - IP: `10.42.0.2/24`
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
- The ER706W management interface (web UI) is on `10.42.0.2` via untagged LAN.
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

**Decision:** Use Option B for now. Create a separate `modules/services/tailscale-yirukou.nix` that configures Tailscale as a subnet router advertising `10.42.0.0/24`, and import it in `hosts/yirukou/services.nix`. Keep the existing shared module for yifuwuqi.

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

modules/services/tailscale-yirukou.nix  — subnet router config
```

### 7.2 Modified files

| File | Change |
|---|---|
| `modules/addresses.nix` | Add `yirukou` entry (see PLAN-yirukou.md §15) |
| `flake.nix` | Add `yirukou` NixOS configuration |
| `hosts/yifuwuqi/networking.nix` | Remove `gateway-failover.nix` import; update LAN to `10.42.0.42/24` |
| `hosts/yifuwuqi/services.nix` | Optionally swap tailscale import to client-only |
| `modules/services/adguardhome.nix` | Prefer on yirukou; update rewrites to `10.42.0.42` |
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
   - Can reach yifuwuqi (once migrated)
4. Connect phone to `iot`:
   - IP: `10.42.20.50+`
   - Gateway: `10.42.20.1`
   - Internet works
   - Cannot `ping 10.42.0.1` or `ping 10.42.0.42`
   - `nslookup google.com 10.42.20.1` works (DNS)
5. Connect phone to `guest`:
   - IP: `10.42.30.50+`
   - Gateway: `10.42.30.1`
   - Internet works
   - Cannot reach any `10.42.x.x` address other than its gateway+DHCP+DNS

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
curl http://10.42.0.42:80  # should FAIL (forward drop)
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
5. ER706W factory reset, configure trunk SSIDs, connect to `lan3`
6. Verify WiFi per SSID works + VLAN isolation
7. Move yifuwuqi to `10.42.0.42`, reconnect to br0 port
8. Update Tailscale route on yirukou; update AdGuard rewrites
9. Move other wired clients to br0 ports
10. Validate all services
