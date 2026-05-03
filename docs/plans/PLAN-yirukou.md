# yirukou - Homelab Gateway Plan

## 1. Summary

yirukou is the new NixOS network appliance for the homelab. It should take over the router/gateway responsibilities that are currently mixed between yifuwuqi and the TP-Link ER706W.

Chosen target LAN:

- Network: `10.42.0.0/24`
- Gateway: `10.42.0.1` on yirukou
- yifuwuqi services host: `10.42.0.2`
- ER706W management/AP IP, if kept as AP: `10.42.0.254`
- lan1, lan2: DHCP clients (yitaishi, yixiaoqing, etc.)

Recommended steady-state topology with current hardware:

- yirukou is the only gateway, firewall, NAT, DHCP, DNS, and Tailscale subnet router.
- ER706W is kept only as an AP-like WiFi bridge with per-SSID VLAN tags.
- yifuwuqi becomes services-only.
- yirukou has two WAN connections: wan0 (ISP modem) and wan1 (ISP2 modem). Both modems use `192.168.1.0/24`, causing a subnet clash on the WAN side. The clash is documented but not solved here — full dual-WAN routing requires VRFs, netns isolation, or reconfiguring one ISP modem to a different subnet.

Best long-term topology:

- Same routed design as above, but replace the ER706W with a real AP such as an Omada EAP650/EAP670, UniFi U6/U7, or similar VLAN-aware AP.
- This removes the ER706W AP-mode workaround while preserving yirukou as the network authority.
- Current recommendation: deploy T1 with the ER706W first, but treat T6 as the best long-term WiFi endpoint if the ER706W workaround is unreliable.

Best migration path:

1. Bootstrap yirukou standalone with one wired client.
2. Cut over to T1 without VLANs first if you want the lowest-risk migration.
3. Add ER706W trunked SSIDs and VLAN isolation after the basic router path works.
4. Consider T3 only if you want to validate yirukou on the current `192.168.0.0/24` network before renumbering.

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
- It can probably be used like an AP by disabling ER706W DHCP/routing, using one LAN port toward yirukou, and configuring SSID VLAN tags.
- For clean T1, prefer no DHCP relay: DHCP broadcasts should reach yirukou directly over the untagged/VLAN bridge path.
- If the firmware does not bridge the desired traffic cleanly, fallback options are DHCP relay per VLAN, a dummy LAN/VLAN setup, or using the ER706W WAN side only for device management.
- In LAN-only/AP-like mode the ER706W itself may not have Internet access for NTP, Omada Cloud, or online firmware checks.
- WiFi clients can still work normally if the switch/SSID VLAN behavior is configured correctly.

## 3. Existing Networks

Current networks already used in this repository / environment:

| Network | Current purpose |
|---|---|---|
| `192.168.0.0/24` | Current ER706W LAN / VPN router network |
| `192.168.1.0/24` | ISP router network, gateway `192.168.1.1` (wan0) |
| `192.168.1.0/24` | ISP2 router network, gateway `192.168.1.1` (wan1) — **clashes with wan0 subnet** |
| `10.0.0.0/24` | ZeroTier |
| `10.88.0.0/16` | Podman |
| `10.100.0.0/24` | WireGuard `wg0` |
| `100.64.0.0/10` | Tailscale |
| `172.17.0.0/16` | Docker pool |
| `172.18.0.0/16` | Docker pool |

Chosen new homelab LAN:

| Item | Value |
|---|---|---|
| LAN subnet | `10.42.0.0/24` |
| yirukou LAN/gateway | `10.42.0.1` |
| yifuwuqi | `10.42.0.2` (lan0) |
| ER706W management IP | `10.42.0.254` |
| lan1, lan2 | DHCP (yitaishi, yixiaoqing, etc.) |

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

## 6. VLAN Plan

VLANs are the preferred steady-state design using a dedicated trunk port (`lan3`) on yirukou connected to the ER706W. The ER706W tags WiFi frames per SSID; yirukou handles all VLAN routing, firewall, and DHCP on the VLAN subinterfaces.

Lower-risk staging option:

- Start with only the untagged trusted LAN/WiFi path.
- Prove yirukou routing, DHCP, DNS, NAT, and Tailscale first.
- Then add VLAN 20 (`iot`) and VLAN 30 (`guest`) on the ER706W trunk.

VLAN layout:

| VLAN | Name | Subnet | Tagging | Purpose |
|---|---|---|---|---|
| *(untagged)* | `lan` | `10.42.0.0/24` | Native on `lan3` | Trusted LAN + ER706W management (`10.42.0.254`) |
| 20 | `iot` | `10.42.20.0/24` | Tagged SSID `iot` | IoT devices, no LAN access |
| 30 | `guest` | `10.42.30.0/24` | Tagged SSID `guest` | Guest WiFi, Internet only |

Trunk (802.1Q) — dedicated port `lan3`:

```
lan3 (physical cable to ER706W LAN port)
 ├── untagged → br0 member          → ER706W management + "homelab" SSID clients
 ├── lan3.20  → VLAN 20 netdev      → gateway 10.42.20.1/24 (iot)
 └── lan3.30  → VLAN 30 netdev      → gateway 10.42.30.1/24 (guest)
```

`lan0`, `lan1`, `lan2` are plain bridge members in `br0` for wired trusted hosts. `lan3` is also a `br0` member so its untagged traffic (ER706W management, homelab SSID WiFi clients) lands on the trusted LAN at L2. The VLAN netdevs `lan3.20` and `lan3.30` are stacked on the raw `lan3` device and are NOT bridge members — they are routed L3 interfaces.

ER706W role: tag SSIDs, bridge frames. No VLAN routing, no DHCP, no firewall.

yirukou owns: all VLAN interfaces, all firewall rules between VLANs, DHCP per VLAN, VLAN-aware NAT.

Full implementation spec: see `PLAN-yirukou-trunk.md`.

## 7. Topology Options

### T1 - yirukou is the only gateway, ER706W is AP-like trunk

Diagram:

```text
ISP router 192.168.1.1        ISP2 router 192.168.1.1
        |                              |
        | 192.168.1.0/24               | 192.168.1.0/24 (clash)
        |                              |
      wan0                           wan1
              \                    /
               \                  /
                  yirukou
                  10.42.0.1
                    |
                    | br0 = 10.42.0.0/24 (lan0,lan1,lan2)
                    |
               +----+-----+------------------+
               |          |                  |
             lan3       lan0               lan1,lan2
            (trunk)   yifuwuqi            DHCP clients
                      10.42.0.2
               |
               | untagged → br0 (ER706W mgmt + homelab SSID)
               | vlan 20  → 10.42.20.0/24 (iot SSID)
               | vlan 30  → 10.42.30.0/24 (guest SSID)
               |
            ER706W
           10.42.0.254
           AP only
```

Description:

- yirukou owns the homelab LAN + VLANs.
- yirukou runs DHCP, DNS, firewall, NAT, Tailscale, and optional VPN egress.
- ER706W is only WiFi AP with per-SSID VLAN tagging.
- ER706W WAN ports are unused.
- `lan3` is a dedicated 802.1Q trunk. Untagged = trusted LAN (br0). Tagged VLAN 20/30 = iot/guest routed subinterfaces.
- `lan0` is wired to yifuwuqi (`10.42.0.2`). `lan1`,`lan2` are DHCP ports for other wired trusted hosts (yitaishi, yixiaoqing).
- `wan1` is a second WAN from ISP2 at the same `192.168.1.0/24` — subnet clash documented, not solved here.

Pros:

- Cleanest no-new-hardware design.
- One homelab routing/NAT policy point. If the ISP router remains upstream, the ISP router may still NAT Internet traffic.
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
- wan1 and wan0 use the same `192.168.1.0/24` subnet; dual-WAN routing needs a solution (VRF, netns, or ISP modem reconfig) before wan1 can be activated.
- If yirukou is down, the LAN gateway is down.
- wan1 subnet clash (`192.168.1.0/24` on both WANs) means wan1 cannot be activated without a solution.
- If the ISP router remains upstream at `192.168.1.1`, Internet egress is still yirukou NAT behind ISP-router NAT.

Verdict:

- Best steady-state choice with current hardware if the ER706W VLAN/AP workaround is stable.

### T1a - yirukou is the only gateway, ER706W is plain untagged WiFi first

Diagram:

```text
ISP router 192.168.1.1        ISP2 router 192.168.1.1
        |                              |
      wan0                           wan1
              \                    /
                  yirukou
                  10.42.0.1
                    |
                  br0 10.42.0.0/24
                    |
             ER706W LAN port
             untagged WiFi only
```

Description:

- yirukou is still the gateway, firewall, DHCP, DNS, NAT, and Tailscale router.
- ER706W initially carries only one untagged trusted SSID.
- VLAN 20/30 SSIDs are added later after the basic routed design is proven.

Pros:

- Lowest-risk T1 migration.
- Lets you debug yirukou WAN/LAN/DHCP/DNS/NAT before involving VLANs.
- Easy to roll back to the ER706W router config if needed.

Cons:

- No IoT/guest isolation until the trunk phase is added.
- Requires a second pass through ER706W WiFi/VLAN setup.

Verdict:

- Best practical staging path for T1.

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
ISP router 192.168.1.1        ISP2 router 192.168.1.1
        |                              |
     yirukou
     10.42.0.1
        |
        +-- real AP, e.g. EAP650 / EAP670 / U6
        +-- yifuwuqi 10.42.0.2
        +-- other clients
```

Description:

- Same as T1 for routing.
- ER706W is sold or retired.
- A purpose-built AP handles WiFi.
- The AP trunk carries the trusted/native SSID plus tagged IoT and guest SSIDs directly to yirukou.
- yirukou remains the router, DHCP server, DNS server, firewall, Tailscale subnet router, and optional VPN egress policy point.

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

- Cleanest long-term overall if buying/replacing WiFi hardware is acceptable.
- T1 first, T6 later is reasonable.

Long-term recommendation:

- Choose T6 as the ideal final shape if the goal is a clean, low-maintenance homelab gateway.
- Choose T1 as the best no-new-hardware target.
- Treat the ER706W as a useful bridge to the final design, not as a component that must be preserved forever.

## 8. Ranking

| Rank | Topology | Role |
|---|---|---|
| 1 | T6 | Best long-term topology if replacing ER706W with a real AP |
| 1 current-hardware | T1 | Best steady-state topology using the ER706W |
| 2 | T1a | Safest T1 staging path |
| 3 | T3 | Best transitional topology if avoiding immediate renumbering |
| 4 | T4 | Niche transparent firewall option |
| 5 | T2 | Only worth it with real multi-WAN needs |
| 6 | T5 | Too limited for the yirukou project |

Recommended path:

1. Target T1 with current hardware, or T6 if buying a real AP is acceptable now.
2. Use `10.42.0.0/24`.
3. Use T1a first if you want a gentler cutover.
4. Keep ER706W initially as AP-like WiFi with DHCP server disabled and DHCP relay disabled unless firmware behavior forces a relay workaround.
5. Add VLAN trunking after basic routing works.
6. Move VPN egress to yirukou if always-on VPN is still needed.
7. Consider T3 only as a temporary staging phase.
8. Treat T6 as the best long-term WiFi option if the ER706W AP workaround is irritating.

## 9. Chosen Target Design: T1 + trunk + `10.42.0.0/24`

Target topology:

```text
ISP router          ISP2 router
192.168.1.1         192.168.1.1
    |                     |
    | DHCP or static      | DHCP or static (clash)
    |                     |
  wan0                  wan1
         \              /
              yirukou
                |
                +-- br0: 10.42.0.1/24 (lan0,lan1,lan2)
                |     +-- lan0 → yifuwuqi, 10.42.0.2
                |     +-- lan1,lan2 → DHCP (yitaishi, yixiaoqing, etc.)
                |
                +-- lan3: trunk to ER706W
                      ├── untagged → br0  (ER706W mgmt 10.42.0.254 + homelab SSID clients)
                      ├── lan3.20 → 10.42.20.1/24  (iot SSID clients)
                      └── lan3.30 → 10.42.30.1/24  (guest SSID clients)
```

Services on yirukou:

- systemd-networkd for WAN, bridge, VLAN netdevs
- nftables firewall (VLAN isolation included)
- NAT from `10.42.0.0/24`, `10.42.20.0/24`, `10.42.30.0/24` to WAN
- systemd-networkd DHCP server on each LAN/VLAN interface
- AdGuardHome for DNS/filtering only, listening on each gateway IP
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

## 10. ER706W Setup for T1 + trunk

Goal:

- ER706W provides WiFi only with per-SSID VLAN tagging.
- yirukou remains the gateway, DHCP server, DNS server, firewall, and NAT for all VLANs.

Recommended sequence:

1. Export / backup current ER706W config.
2. Factory reset ER706W for a clean baseline.
3. Initial setup from a directly connected laptop.
4. Configure LAN:
   - IP: `10.42.0.254`
   - Netmask: `255.255.255.0`
   - Gateway: `10.42.0.1`, if the firmware allows it in LAN/AP-like mode
   - DNS: `10.42.0.1`, if the firmware allows it in LAN/AP-like mode
   - DHCP server: disabled
   - DHCP relay: disabled (yirukou serves DHCP directly on each VLAN interface)
5. Configure WAN:
   - Connection type: Dynamic IP
   - Status: disconnected
   - WAN cable: unplugged
6. Configure SSIDs with VLAN tagging:
   - SSID `homelab`: untagged (native VLAN, clients land on 10.42.0.0/24)
   - SSID `iot`: VLAN ID 20 (clients land on 10.42.20.0/24)
   - SSID `guest`: VLAN ID 30 (clients land on 10.42.30.0/24)
   - Security: WPA3-Personal (or WPA2/WPA3 mixed)
   - WPS: disabled
7. Disable ER706W features no longer used:
   - VPN server/client
   - port forwards
   - static routes
   - policy routing
   - NAT rules
   - DHCP server
   - DHCP relay
8. Physical cabling:
   - ER706W LAN port → yirukou `lan3` (trunk port)
   - ER706W WAN port unplugged
9. Test from each SSID:
   - `homelab` client gets `10.42.0.x`, gateway `10.42.0.1`, DNS `10.42.0.1`, Internet works
   - `iot` client gets `10.42.20.x`, gateway `10.42.20.1`, DNS `10.42.20.1`, Internet works, cannot reach `10.42.0.x`
   - `guest` client gets `10.42.30.x`, gateway `10.42.30.1`, DNS `10.42.30.1`, Internet works, cannot reach `10.42.0.x` or `10.42.20.x`

Known limitations:

- ER706W may not reach Internet itself in this mode.
- Some firmware builds may not allow a useful LAN-side default gateway; verify on the actual UI.
- If management/NTP/firmware updates matter, either temporarily reconnect WAN, use the ER706W WAN-management workaround, or replace it with a real AP.
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
| `10.42.0.2` yifuwuqi | direct ISP |
| `10.42.0.x` yitaishi (DHCP) | VPN |
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
  - Update `yifuwuqi.network.lan` to `10.42.0.2/24`, gateway `10.42.0.1`.
- `flake.nix`
  - Add `yirukou` NixOS configuration.
- `hosts/yifuwuqi/networking.nix`
  - Remove router/failover duties.
  - Drop `gateway-failover.nix` import if yifuwuqi is no longer a gateway.
- `modules/services/tailscale.nix`
  - Make route advertisement and exit-node behavior per-host configurable.
  - Move `10.42.0.0/24` subnet advertisement to yirukou.
  - Stop hardcoding yifuwuqi as the only server/exit node.
- `modules/services/adguardhome.nix`
  - Split gateway DNS from services-host rewrites.
  - Keep service records such as `*.fufu.land` pointing at yifuwuqi (`10.42.0.2`) unless the reverse proxy also moves.
  - Prefer AdGuardHome DNS on yirukou, with yifuwuqi optional as secondary DNS.
  - Decide how DNS-over-TLS/HTTPS certificates are provided on yirukou if those listeners are kept.
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
      # DHCP from ISP2 router at 192.168.1.1
      # WARNING: subnet clash with wan0 (both 192.168.1.0/24).
      # Activating wan1 requires VRF, netns isolation, or ISP modem reconfig.
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

    # br0 member ports
    lanInterfaces = [ "lan0" "lan1" "lan2" ];

    # Trunk port to ER706W (also a br0 member for untagged traffic)
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
        host = "100.69.0.2"; # pick next free
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

## 16. Greenfield T1/T1a Implementation Order

1. Confirm T1/T1a/T6 path and subnet `10.42.0.0/24`.
2. Add yirukou to `modules/addresses.nix` (include trunk + VLAN entries).
3. Create `hosts/yirukou/*` (networking.nix with bridge, optional VLAN netdevs, DHCP, NAT, and firewall).
4. Add yirukou to `flake.nix`.
5. Install / bootstrap yirukou.
6. Connect yirukou `wan0` to ISP router. Verify Internet.
7. Enable systemd-networkd DHCP, AdGuardHome DNS, NAT, and base firewall on yirukou.
8. Test a wired laptop on `lan0` before moving the rest of the LAN.
9. Optional T1a stage: configure ER706W as one untagged trusted SSID only, DHCP disabled, and connect it to yirukou.
10. Move yifuwuqi to `10.42.0.2`, connect to `br0` port (lan0).
11. Update Tailscale advertised route to `10.42.0.0/24`.
12. Update AdGuard rewrites while keeping service hostnames on yifuwuqi.
13. Reconfigure ER706W with per-SSID VLAN tagging (section 10).
14. Connect ER706W LAN port to yirukou `lan3` (trunk).
15. Renew DHCP leases on clients.
16. Verify per-SSID isolation:
    - `homelab`: `10.42.0.x`, gateway `10.42.0.1`, DNS `10.42.0.1`, Internet works
    - `iot`: `10.42.20.x`, gateway `10.42.20.1`, DNS `10.42.20.1`, Internet works, cannot reach `10.42.0.x`
    - `guest`: `10.42.30.x`, gateway `10.42.30.1`, DNS `10.42.30.1`, Internet works, cannot reach `10.42.0.x` or `10.42.20.x`
    - internal services resolve and connect from trusted LAN

Rollback plan:

1. Restore the backed-up ER706W config.
2. Reconnect clients to the old ER706W LAN.
3. Restore yifuwuqi to `192.168.0.42/24` with gateway `192.168.0.1`.
4. Re-enable ER706W DHCP.
5. Disable or disconnect yirukou until the config is fixed.

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
3. Change yifuwuqi to `10.42.0.2`.
4. Reconfigure ER706W as AP-like WiFi at `10.42.0.254`, with DHCP relay disabled unless the firmware requires a relay workaround.
5. Move yirukou WAN to ISP router.
6. Move LAN clients to yirukou br0 / ER706W AP.
7. Update Tailscale route to `10.42.0.0/24`.
8. Update AdGuard rewrites.
9. Remove transitional `192.168.0.0/24` routing rules.

## 18. Open Questions

Decided:

| Question | Decided answer |
|---|---|
| Final topology | T6 is best long-term if replacing WiFi hardware; T1 is best with current hardware |
| LAN subnet | `10.42.0.0/24` |
| VLANs | Preferred steady state: 802.1Q trunk with VLAN 20 (iot) + 30 (guest); T1a can stage untagged first |
| ER706W | Keep as AP-like WiFi bridge if firmware works; replace with real AP if annoying |
| VPN egress | Drop initially or reimplement on yirukou |
| Encryption | WPA3 + Tailscale everywhere baseline |
| Migration | T1a first, direct T1 trunk if confident, or T3 staging if risk needs to be lower |
| Best long-term WiFi endpoint | Purpose-built VLAN-aware AP; keep ER706W only if the workaround behaves well |

Still to decide:

1. Direct T1 cutover, T1a first, or T3 old-subnet staging?
2. Keep ER706W as AP long-term, or replace with a real AP for the final design?
3. Do we need always-on VPN egress, or is Tailscale exit-node usage enough?
## 19. Hardening and Minimalism

yirukou is designed as a secure, headless network appliance. Following the deprecation of `linuxPackages_hardened` and the `hardened` profile in NixOS unstable (as of early 2026), a new first-party approach is adopted using enhanced `serverMode` options.

### Strategy
- **Base Kernel**: Use `pkgs.linuxPackages_latest` (or standard LTS) instead of the removed hardened alias.
- **Declarative Lockdown**: Leverage NixOS-native `security.*` and `boot.kernel.sysctl.*` options.
- **Categorization**: 
  - `serverMode.headless`: baseline minimalism for all servers (yifuwuqi, yirukou).
  - `serverMode.appliance`: extreme lockdown for gateway appliances (yirukou).

### Planned Implementation (`modules/server-mode.nix`)

The `serverMode` module will be expanded to support these roles:

| Category | Option | Key Settings |
| :--- | :--- | :--- |
| **Minimalism** | `headless = true` | Disable: GUI, Docs, Fonts, command-not-found, XDG sounds/icons/mime. |
| **Hardening** | `appliance = true` | Enable: `lockKernelModules`, `protectKernelImage`, `unprivilegedUsernsRestrict`. |
| **Network** | `appliance = true` | Sysctl: `kptr_restrict=2`, `unprivileged_bpf_disabled=1`, `bpf_jit_harden=2`, disable ICMP redirects. |

### Impact on yirukou
- `yirukou` will enable both `headless` and `appliance` modes.
- This creates a "read-only" style runtime environment where new modules cannot be loaded and kernel memory is protected.
- **Note**: `unprivilegedUsernsRestrict` is acceptable here as yirukou is not intended to run rootless containers (like Podman).

### Impact on yifuwuqi
- `yifuwuqi` will enable `headless` only.
- This provides the space-saving benefits of minimalism (no fonts/docs) while maintaining compatibility for its Podman workload (which requires User Namespaces).
