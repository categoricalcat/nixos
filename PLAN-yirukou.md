# yirukou - Homelab Gateway Plan

## 1. Summary

yirukou is the new NixOS network appliance for the homelab. It should take over the router/gateway responsibilities that are currently mixed between yifuwuqi and the TP-Link ER706W.

Chosen target LAN:

- Network: `10.42.0.0/24`
- Gateway: `10.42.0.1` on yirukou
- ER706W management/AP IP, if kept as AP: `10.42.0.2`
- yifuwuqi services host: `10.42.0.42`

Recommended long-term topology:

- yirukou is the only gateway, firewall, NAT, DHCP, DNS, and Tailscale subnet router.
- ER706W is kept only as a WiFi access point and optional DHCP relay.
- yifuwuqi becomes services-only.

Best migration path:

1. Optionally stage yirukou on the current `192.168.0.0/24` network first.
2. Then cut over to the clean `10.42.0.0/24` network.

## 2. Hardware

### yirukou

- 6-port 2.5G NIC appliance
- Intel Pentium 8505, 8 GB DDR5
- Planned roles:
  - Gateway
  - Firewall
  - NAT
  - DHCP
  - DNS
  - Tailscale exit node / subnet router
  - Optional WireGuard egress client for selected hosts

### TP-Link ER706W

- Omada AX3000 WiFi 6 VPN gateway
- WiFi: 574 Mbps on 2.4 GHz, 2402 Mbps on 5 GHz
- Ports: 1x SFP WAN/LAN, 1x fixed RJ45 WAN, 4x RJ45 WAN/LAN, USB 3.0 for LTE backup
- Supports:
  - Multi-WAN load balancing
  - 802.1Q VLANs
  - Wireless VLAN per SSID
  - DHCP server
  - DHCP relay
  - WireGuard, IPsec, OpenVPN, PPTP, L2TP, GRE, SSL VPN
- Approx throughput:
  - NAT: about 940 Mbps
  - WireGuard: about 393 Mbps
  - IPsec AES256: about 650 Mbps

Important ER706W caveat:

- It does not have a real official "AP only" mode.
- It can be used like an AP by disabling WAN use, disabling DHCP server, enabling DHCP relay, and connecting one LAN port to yirukou.
- In that AP-like mode the ER706W itself may not have Internet access for NTP, Omada Cloud, or online firmware checks.
- WiFi clients still work normally if DHCP relay / bridge behavior is configured correctly.

## 3. Existing Networks

Current networks already used in this repository / environment:

| Network | Current purpose |
|---|---|
| `192.168.0.0/24` | Current ER706W LAN / VPN router network |
| `192.168.1.0/24` | ISP router network, gateway `192.168.1.1` |
| `10.0.0.0/24` | ZeroTier |
| `10.88.0.0/16` | Podman |
| `10.100.0.0/24` | WireGuard `wg0` |
| `100.64.0.0/10` | Tailscale |
| `172.17.0.0/16` | Docker pool |
| `172.18.0.0/16` | Docker pool |

Chosen new homelab LAN:

| Item | Value |
|---|---|
| LAN subnet | `10.42.0.0/24` |
| yirukou LAN/gateway | `10.42.0.1` |
| ER706W management IP | `10.42.0.2` |
| yifuwuqi | `10.42.0.42` |
| yitaishi | `10.42.0.43` or DHCP reservation |
| yixiaoqing | `10.42.0.44` or DHCP reservation |

Why `10.42.0.0/24`:

- Avoids the current ER706W network (`192.168.0.0/24`).
- Avoids the ISP router network (`192.168.1.0/24`).
- Avoids common hotel/cafe LANs, which helps Tailscale subnet routing when roaming.
- Easy to remember.

## 4. Goals

Primary goals:

- Make yirukou the real network authority.
- Keep the topology easy to debug.
- Keep DHCP, DNS, firewall, NAT, and Tailscale routing declarative in NixOS.
- Preserve the option for per-host VPN egress.
- Keep yifuwuqi focused on services.
- Reuse the ER706W if it does not make the design worse.

Non-goals:

- Do not optimize for ER706W multi-WAN unless there is actually a second WAN feed.
- Do not keep `192.168.0.0/24` just to avoid renumbering if it causes a worse long-term architecture.
- Do not preserve the ER706W VPN-client role if yirukou can do the same job more cleanly.

## 5. Subnet Options

The selected subnet is `10.42.0.0/24`, but the options considered were:

| Code | Subnet | Gateway | Notes |
|---|---|---|---|
| S1 | `10.42.0.0/24` | `10.42.0.1` | Selected. Distinct, memorable, avoids upstream `192.168.x`. |
| S2 | `10.50.0.0/24` | `10.50.0.1` | Also clean, but not selected. |
| S3 | `192.168.10.0/24` | `192.168.10.1` | Familiar but easier to confuse with current `192.168.0.0/24`. |
| S4 | `192.168.50.0/24` | `192.168.50.1` | Common homelab choice, but still in crowded `192.168.x`. |
| S5 | `172.20.0.0/24` | `172.20.0.1` | Low collision risk, less memorable. |
| S6 | `192.168.0.0/24` | `192.168.0.1` or `.2` | Existing network. Useful only for transitional designs. |

## 6. Optional VLAN Plan

Start flat unless there is an immediate need for IoT / guest isolation. VLANs can be added later.

Suggested VLAN layout if enabled:

| VLAN | Name | Subnet | Purpose |
|---|---|---|---|
| 10 | `lan` | `10.42.0.0/24` | Trusted LAN, wired plus main WiFi |
| 20 | `iot` | `10.42.20.0/24` | IoT devices, no LAN access |
| 30 | `guest` | `10.42.30.0/24` | Guest WiFi, Internet only |
| 99 | `mgmt` | `10.42.99.0/24` | AP/switch management |

If VLANs are used, yirukou owns all VLAN interfaces and firewall rules. The ER706W should only tag SSIDs and bridge frames.

## 7. Topology Options

### T1 - yirukou is the only gateway, ER706W is AP only

Diagram:

```text
ISP router 192.168.1.1
        |
        | 192.168.1.0/24
        |
      wan0
   yirukou
   10.42.0.1
        |
        | br0 = 10.42.0.0/24
        |
   +----+-----+------------------+
   |          |                  |
ER706W     yifuwuqi           other LAN hosts
10.42.0.2  10.42.0.42         10.42.0.x
AP only
```

Description:

- yirukou owns the homelab LAN.
- yirukou runs DHCP, DNS, firewall, NAT, Tailscale, and optional VPN egress.
- ER706W is only WiFi AP + optional DHCP relay.
- ER706W WAN ports are unused.

Pros:

- Cleanest long-term design.
- One NAT layer.
- One gateway.
- One DHCP server.
- One DNS policy.
- One firewall.
- Real client IPs are visible to AdGuard and yirukou firewall logs.
- Per-host VPN egress is easy on yirukou with nftables / policy routing.
- Best fit for NixOS declarative networking.
- Best fit for Tailscale-everywhere encryption.
- yirukou hardware is fully used.

Cons:

- Requires renumbering from `192.168.0.0/24` to `10.42.0.0/24`.
- Requires reconfiguring ER706W into AP-like mode.
- ER706W AP-like mode has caveats: no proper AP mode, possible no NTP / Omada Cloud.
- ER706W multi-WAN features are unused.
- If yirukou is down, the LAN gateway is down.

Verdict:

- Best steady-state choice.

### T2 - ER706W is WAN aggregator, yirukou is behind it, WiFi is VLAN-trunked back

Diagram:

```text
WAN1/ISP1 ----+
              |
WAN2/ISP2 ----+--> ER706W
                    |
                    | trunk to yirukou
                    | untagged: yirukou WAN on 192.168.0.0/24
                    | tagged VLAN 10: WiFi clients bridged to yirukou LAN
                    |
                 yirukou
                 WAN: 192.168.0.x
                 LAN: 10.42.0.1
                    |
                 br0 10.42.0.0/24
```

Description:

- ER706W receives the WAN feeds and keeps multi-WAN / VPN-client duties.
- yirukou sits behind ER706W.
- WiFi clients from ER706W are VLAN-tagged and bridged back into yirukou LAN.
- This lets WiFi clients use yirukou DHCP/DNS/gateway even though the ER706W is upstream.

Pros:

- Preserves ER706W multi-WAN.
- Preserves ER706W VPN egress.
- WiFi clients can still land on yirukou's `10.42.0.0/24` LAN.
- Useful if there are truly two WAN feeds and ER706W must manage them.

Cons:

- Double NAT: yirukou NAT plus ER706W NAT.
- More complex VLAN trunking.
- More failure modes.
- Two firewall/policy surfaces.
- Port forwarding becomes ER706W -> yirukou -> service.
- Per-host VPN egress is harder because ER706W controls egress.
- MTU issues are more likely with VPN encapsulation.
- Overcomplicated if there is only one upstream Internet path.

Verdict:

- Only choose this if there are actually two WAN feeds and ER706W must handle them.

### T3 - ER706W stays edge, yirukou is gateway in the same `192.168.0.0/24`

Diagram:

```text
ISP router / WAN
        |
     ER706W
     192.168.0.1
        |
        | same L2 network: 192.168.0.0/24
        |
     yirukou
     192.168.0.2
     DHCP gives:
       gateway = 192.168.0.2
       DNS     = 192.168.0.2
        |
    clients remain 192.168.0.x
```

Description:

- ER706W remains the Internet entry point.
- yirukou joins the existing ER706W LAN as `192.168.0.2`.
- yirukou runs DHCP and tells clients that yirukou is their default gateway.
- yirukou forwards to ER706W.
- yirukou must SNAT outbound traffic to avoid asymmetric routing.
- yirukou must disable ICMP redirects.

Why SNAT is required:

- Client sends outbound traffic to yirukou.
- yirukou forwards it to ER706W.
- ER706W sees the destination return path as directly attached to `192.168.0.0/24`.
- Without SNAT, replies may go ER706W -> client directly, bypassing yirukou.
- That breaks stateful firewalling and defeats the point of yirukou as gateway.
- SNAT makes replies return to yirukou.

Pros:

- Minimal disruption.
- No immediate renumbering.
- Keeps yifuwuqi at `192.168.0.42`.
- Keeps ER706W WAN / VPN setup intact.
- Fast rollback: turn ER706W DHCP back on.
- Good transitional topology to validate yirukou hardware and NixOS config.

Cons:

- Weird long-term design.
- Effective double NAT even though it is one subnet.
- ER706W sees only yirukou, not real clients.
- yirukou needs hairpin-style SNAT on same network.
- Must disable ICMP redirects.
- Per-host VPN egress is still controlled by ER706W, not yirukou.
- Easy for future-you to forget why it is configured this way.

Verdict:

- Best temporary staging option.
- Not recommended as final topology.

### T4 - yirukou as transparent L2 bridge

Diagram:

```text
ISP/WAN
  |
ER706W 192.168.0.1
  |
  | physical cable
  |
yirukou as bridge / bump-in-the-wire
  |
  | downstream LAN
  |
clients 192.168.0.x
```

Description:

- yirukou is inserted physically between ER706W and clients.
- yirukou bridges L2 frames rather than acting as an L3 gateway.
- ER706W remains the client default gateway.
- yirukou can filter with nftables bridge family.

Pros:

- Single NAT layer.
- No renumbering.
- ER706W keeps real client visibility.
- Symmetric traffic path.
- yirukou can inspect/filter traffic if bridge firewalling is enabled.

Cons:

- yirukou is not really the gateway.
- More niche and harder to reason about.
- Bridge firewalling is less familiar than normal routed firewalling.
- If yirukou fails, the physical path is broken.
- Per-host VPN egress still belongs to ER706W.
- Does not use yirukou as the intended router appliance.

Verdict:

- Useful for transparent firewall / IDS experiments.
- Not the best homelab gateway design.

### T5 - yirukou is service host only

Diagram:

```text
ISP/WAN
  |
ER706W 192.168.0.1
  |
  | 192.168.0.0/24
  |
yirukou 192.168.0.2
AdGuard/DHCP/services only
```

Description:

- ER706W remains the router/gateway/firewall/VPN device.
- yirukou is just another LAN host.
- yirukou may run AdGuardHome and DHCP.
- yirukou does not route traffic.

Pros:

- Simplest deployment.
- No renumbering.
- No double NAT if ER706W remains gateway.
- If yirukou fails, basic routing may still work.

Cons:

- yirukou is not a gateway.
- Wastes the 6-port router appliance.
- No yirukou firewall control.
- No yirukou per-host routing.
- Does not meet the purpose of the project.

Verdict:

- Fine if the only goal is DNS/DHCP.
- Not appropriate for a gateway build.

### T6 - Replace ER706W with a real AP

Diagram:

```text
ISP router 192.168.1.1
        |
     yirukou
     10.42.0.1
        |
        +-- real AP, e.g. EAP650 / EAP670 / U6
        +-- yifuwuqi 10.42.0.42
        +-- other clients
```

Description:

- Same as T1 for routing.
- ER706W is sold or retired.
- A purpose-built AP handles WiFi.

Pros:

- All T1 network benefits.
- No ER706W AP-mode workaround.
- AP can have normal gateway, NTP, firmware updates, controller adoption.
- Better long-term WiFi experience.
- ER706W resale may cover the AP cost.

Cons:

- Requires buying another AP.
- Requires selling or storing the ER706W.
- Slightly more setup work if controller-managed.

Verdict:

- Cleanest long-term if the ER706W AP workaround becomes annoying.
- T1 first, T6 later is reasonable.

## 8. Ranking

| Rank | Topology | Role |
|---|---|---|
| 1 | T1 | Best steady-state topology with current hardware |
| 1 alt | T6 | Best steady-state if replacing ER706W with a real AP |
| 2 | T3 | Best transitional topology |
| 3 | T4 | Niche transparent firewall option |
| 4 | T2 | Only worth it with real multi-WAN needs |
| 5 | T5 | Too limited for the yirukou project |

Recommended path:

1. Target T1.
2. Use `10.42.0.0/24`.
3. Keep ER706W initially as AP + DHCP relay.
4. Move VPN egress to yirukou if always-on VPN is still needed.
5. Consider T3 only as a temporary staging phase.
6. Consider T6 later if the ER706W AP workaround is irritating.

## 9. Chosen Target Design: T1 + `10.42.0.0/24`

Target topology:

```text
ISP router
192.168.1.1
    |
    | DHCP or static on yirukou wan0
    |
yirukou
wan0: 192.168.1.x
br0:  10.42.0.1/24
    |
    +-- ER706W AP, 10.42.0.2
    +-- yifuwuqi, 10.42.0.42
    +-- yitaishi, 10.42.0.43 or DHCP reservation
    +-- yixiaoqing, 10.42.0.44 or DHCP reservation
```

Services on yirukou:

- systemd-networkd for WAN, bridge, optional VLANs
- nftables firewall
- NAT from `10.42.0.0/24` to WAN
- AdGuardHome for DNS and DHCP
- Tailscale exit node / subnet router advertising `10.42.0.0/24`
- SSH for admin
- Netdata for gateway monitoring
- Optional WireGuard egress client

Services on yifuwuqi:

- AI stack
- nginx reverse proxy / WebDAV
- Samba
- Cloudflared
- SearXNG
- MariaDB
- Cockpit
- Portainer
- Secondary DNS, if desired

## 10. ER706W Setup for T1

Goal:

- ER706W provides WiFi only.
- yirukou remains the gateway, DHCP server, DNS server, firewall, and NAT.

Recommended sequence:

1. Export / backup current ER706W config.
2. Factory reset ER706W for a clean baseline.
3. Initial setup from a directly connected laptop.
4. Configure LAN:
   - IP: `10.42.0.2`
   - Netmask: `255.255.255.0`
   - DHCP server: disabled
   - DHCP relay: enabled
   - DHCP relay target: `10.42.0.1`
5. Configure WAN:
   - Connection type: Dynamic IP
   - Status: disconnected
   - WAN cable: unplugged
6. Configure WiFi:
   - Main SSID: `homelab`
   - Security: WPA3-Personal if all clients support it
   - Fallback: WPA2/WPA3 mixed if needed
   - WPS: disabled
7. Optional SSIDs:
   - `iot` -> VLAN 20
   - `guest` -> VLAN 30
8. Disable ER706W features no longer used:
   - VPN server/client
   - port forwards
   - static routes
   - policy routing
   - NAT rules
   - DHCP server
9. Physical cabling:
   - ER706W LAN port -> yirukou LAN/br0 port
   - ER706W WAN port unplugged
10. Test from WiFi:
   - Client gets `10.42.0.x`
   - Client gateway is `10.42.0.1`
   - Client DNS is `10.42.0.1`
   - Client reaches Internet

Known limitations:

- ER706W may not reach Internet itself in this mode.
- Firmware updates may need manual upload or temporary WAN reconnect.
- NTP / Omada Cloud may not work unless using a workaround.
- If this becomes annoying, replace with a real AP.

## 11. VPN Egress Choices

### Option V1 - Drop always-on VPN egress

- Use Tailscale exit nodes or per-device VPN clients when needed.
- Simplest.
- Recommended unless always-on VPN egress is a hard requirement.

### Option V2 - Move VPN egress to yirukou

- yirukou runs a WireGuard client to the VPN provider.
- nftables marks traffic by source IP or VLAN.
- Policy routing sends selected hosts through the VPN tunnel.

Example policy:

| Source | Egress |
|---|---|
| `10.42.0.42` yifuwuqi | direct ISP |
| `10.42.0.43` yitaishi | VPN |
| `10.42.20.0/24` IoT | direct or blocked |
| `10.42.30.0/24` guest | direct ISP |

Pros:

- Strong per-host control.
- Fully declarative in NixOS.
- ER706W no longer owns egress policy.

Cons:

- More NixOS routing work.
- Need MTU handling.
- Need kill-switch firewall rule so selected hosts do not leak if VPN drops.

### Option V3 - Keep VPN egress on ER706W

- Only makes sense for T2/T3/T4/T5.
- Not compatible with clean T1 unless ER706W stays upstream.

Pros:

- Keeps existing ER706W VPN config.

Cons:

- yirukou loses per-host egress authority.
- Harder to reason about from NixOS.
- Often forces double NAT or awkward topology.

## 12. Network Encryption

Question:

- Can the whole network be encrypted?

Answer:

- WiFi can be encrypted with WPA3.
- Host-to-host traffic can be encrypted with Tailscale/WireGuard.
- Ethernet link encryption with MACsec is only possible on links where both ends support it.
- A fully encrypted physical LAN is possible only with compatible switches/NICs and more operational complexity.

Recommended practical baseline:

1. WPA3-Personal on all WiFi SSIDs.
2. Disable WPS.
3. Put legacy/IoT devices on a separate VLAN if VLANs are enabled.
4. Run Tailscale on yirukou, yifuwuqi, yitaishi, and yixiaoqing.
5. Use Tailscale IPs / MagicDNS names for internal services.
6. Bind internal admin services to `tailscale0` where possible.
7. Use HTTPS for web services.
8. Enable Samba encryption if Samba is exposed beyond trusted LAN.
9. Consider DNS over TLS to AdGuardHome if local DNS privacy matters.

MACsec notes:

- yirukou's NICs may support MACsec if they are Intel i225/i226 class.
- ER706W does not appear to support MACsec.
- Most consumer switches/APs do not support MACsec.
- Do not make MACsec a day-one requirement.

## 13. Files to Create

```text
hosts/yirukou/
|-- configuration.nix
|-- hardware.nix
|-- addresses.nix
|-- networking.nix
|-- services.nix
`-- boot.nix
```

## 14. Files to Modify

- `modules/addresses.nix`
  - Add `yirukou`.
  - Update `yifuwuqi.network.lan` to `10.42.0.42/24`, gateway `10.42.0.1`.
- `flake.nix`
  - Add `yirukou` NixOS configuration.
- `hosts/yifuwuqi/networking.nix`
  - Remove router/failover duties.
  - Drop `gateway-failover.nix` import if yifuwuqi is no longer a gateway.
- `modules/services/tailscale.nix`
  - Change advertised LAN route from `192.168.0.0/24` to `10.42.0.0/24`.
  - Move subnet advertisement to yirukou.
- `modules/services/adguardhome.nix`
  - Update rewrites from `192.168.0.42` to `10.42.0.42`.
  - Prefer AdGuardHome on yirukou, with yifuwuqi optional as secondary DNS.
- `modules/networking/firewall.nix`
  - Review container egress rules that currently treat `192.168.0.0/16` specially.
  - Add / allow `10.42.0.0/24` where appropriate.

## 15. Address Registry Sketch

```nix
yirukou = rec {
  hostName = "yirukou";

  network = {
    wan = {
      interface = "wan0";
      # DHCP from ISP router at 192.168.1.1
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

    lanInterfaces = [ "lan0" "lan1" "lan2" "lan3" ];

    vlans = {
      iot = {
        id = 20;
        ipv4 = {
          cidr = "10.42.20.0/24";
          host = "10.42.20.1";
          prefixLength = 24;
        };
      };

      guest = {
        id = 30;
        ipv4 = {
          cidr = "10.42.30.0/24";
          host = "10.42.30.1";
          prefixLength = 24;
        };
      };

      mgmt = {
        id = 99;
        ipv4 = {
          cidr = "10.42.99.0/24";
          host = "10.42.99.1";
          prefixLength = 24;
        };
      };
    };

    tailscale = {
      interface = "tailscale0";
      ipv4 = rec {
        cidr = "100.64.0.0/10";
        host = "100.69.0.X"; # pick next free, e.g. 100.69.0.2
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

## 16. Greenfield T1 Implementation Order

1. Confirm T1 and subnet `10.42.0.0/24`.
2. Add yirukou to `modules/addresses.nix`.
3. Create `hosts/yirukou/*`.
4. Add yirukou to `flake.nix`.
5. Install / bootstrap yirukou.
6. Connect yirukou WAN to ISP router.
7. Verify yirukou has Internet.
8. Enable yirukou DHCP/DNS/NAT/firewall.
9. Reconfigure ER706W as AP + DHCP relay.
10. Connect ER706W LAN port to yirukou LAN/br0.
11. Move yifuwuqi to `10.42.0.42`.
12. Update Tailscale advertised route to `10.42.0.0/24`.
13. Update AdGuard rewrites.
14. Renew DHCP leases on clients.
15. Verify wired and WiFi clients:
    - IP in `10.42.0.0/24`
    - gateway `10.42.0.1`
    - DNS `10.42.0.1`
    - Internet works
    - internal services resolve and connect

## 17. Transitional T3 Implementation Order

Use this only if you want to validate yirukou before renumbering.

Stage 1:

1. Add yirukou at `192.168.0.2/24`.
2. Keep ER706W at `192.168.0.1`.
3. yirukou runs DHCP on `192.168.0.0/24`.
4. DHCP gives:
   - gateway: `192.168.0.2`
   - DNS: `192.168.0.2`
5. yirukou forwards to `192.168.0.1`.
6. yirukou SNATs forwarded client traffic.
7. Disable ICMP redirects on yirukou.
8. Disable ER706W DHCP.
9. Validate for a few days.

Stage 2:

1. Schedule downtime.
2. Change yirukou LAN to `10.42.0.1/24`.
3. Change yifuwuqi to `10.42.0.42`.
4. Reconfigure ER706W as AP + DHCP relay at `10.42.0.2`.
5. Move yirukou WAN to ISP router.
6. Move LAN clients to yirukou br0 / ER706W AP.
7. Update Tailscale route to `10.42.0.0/24`.
8. Update AdGuard rewrites.
9. Remove transitional `192.168.0.0/24` routing rules.

## 18. Open Questions

Current assumed answers:

| Question | Assumed answer |
|---|---|
| Final topology | T1 |
| LAN subnet | `10.42.0.0/24` |
| VLANs day one | No, flat LAN first |
| ER706W | Keep as AP + DHCP relay first |
| VPN egress | Drop initially or reimplement on yirukou |
| Encryption | WPA3 + Tailscale everywhere baseline |
| Migration | Direct T1, or T3 staging if risk needs to be lower |

Still to decide:

1. Direct T1 cutover, or T3 staging first?
2. Keep ER706W as AP long-term, or replace with a real AP later?
3. Do we need always-on VPN egress, or is Tailscale exit-node usage enough?
4. Add VLANs immediately, or after the flat LAN is stable?
