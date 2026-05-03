# Addendum: yirukou Public Static IP Security Precautions

This plan extends the `PLAN-yirukou-trunk.md` and `PLAN-yirukou.md` specifications to account for direct exposure to a public static IP on the `wan0` interface.

## 1. Objective
Harden the `yirukou` router against internet-facing threats specific to static public IP addresses while maintaining the integrity of the planned VLAN and VPN topology.

## 2. Key Files & Context
- `secrets/secrets.yaml` & `secrets/sops.nix` (for storing the static IP)
- `hosts/yirukou/networking.nix` (nftables modifications)

## 3. Implementation Steps

### Step 3.1: SOPS Integration for Static IP
Instead of setting up DDNS, the static IP will be treated as infrastructure state.
1. Add the public IP to `secrets.yaml`:
   ```yaml
   public_ip: "YOUR.STATIC.IP.ADDRESS"
   ```
2. Make it accessible in NixOS for future use (e.g., firewall whitelisting on remote VPS instances):
   ```nix
   sops.secrets.public_ip = {};
   ```

### Step 3.2: Update nftables Rules (networking.nix)
Modify the `networking.nftables.tables.yirukou` block from the original plan to include edge hardening. 

**Changes to be injected:**
1. **Invalid State Drop:** Drop malformed packets bypassing state tracking immediately in both `input` and `forward` chains.
2. **Bogon Filter:** Drop private/reserved IP ranges arriving on the physical `wan0` interface (prevents IP spoofing). *Note: This does not affect VPN interfaces like Tailscale because they process decrypted traffic on virtual interfaces (`tailscale0`), bypassing `wan0` rules.*
3. **ICMP Rate Limiting:** Replace blanket ICMP allowances with a strict rate limit (5 pings/second) to prevent ping floods.
4. **Log Exhaustion Prevention:** Remove the blanket `log prefix "yirukou-input-drop: "` rule that would otherwise fill system journals with internet background noise, replacing it with a silent `counter drop` for internet traffic, logging only LAN-originating drops.

**Updated nftables snippet:**
```nix
    # ── FORWARD (inter-VLAN isolation) ─────────────────────
    chain forward {
      type filter hook forward priority filter; policy drop;

      # NEW: Drop malformed packets immediately
      ct state invalid drop

      # NEW: Bogon filter on physical WAN
      iifname ''${wan} ip saddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10 } drop

      # Allow outbound from all LAN subnets to Internet
      iifname ''${lanIfs} oifname ''${wan} accept
      iifname ''${wan} oifname ''${lanIfs} ct state established,related accept

      # ... (Existing VLAN isolation rules remain exactly the same) ...

      counter drop
    }

    # ── INPUT (to yirukou itself) ──────────────────────────
    chain input {
      type filter hook input priority filter; policy drop;

      # NEW: Drop malformed packets immediately
      ct state invalid drop

      # NEW: Bogon filter on physical WAN
      iifname ''${wan} ip saddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10 } drop

      # Loopback
      iifname lo accept

      # Established/related
      ct state established,related accept

      # NEW: ICMP Rate limiting (allows external ping testing but prevents floods)
      ip protocol icmp icmp type echo-request limit rate 5/second accept
      ip6 nexthdr ipv6-icmp icmpv6 type echo-request limit rate 5/second accept

      # ... (Existing SSH, DHCP, DNS, and Tailscale rules remain exactly the same) ...

      # NEW: Log only LAN-originating drops, silently drop internet noise
      iifname ''${lanIfs} log prefix "yirukou-lan-drop: " counter drop
      counter drop
    }
```

## 4. Verification & Testing
1. **Bogon Verification:** Run `nft list ruleset` and ensure the bogon filters are evaluated *before* the accept rules in both `input` and `forward`.
2. **VPN Integrity:** Ensure a device on the Tailscale network (e.g., `100.x.x.x` or acting as subnet router for `10.x.x.x`) can still reach yirukou. The `iifname ''${tsIf} accept` rule will properly trigger because the interface name matches, ignoring the `wan0` restriction.
3. **Log Check:** Run `journalctl -f -k | grep yirukou` while exposing the server to the internet to verify that random port scans (from `wan0`) are NOT polluting the logs, while a blocked attempt from the guest VLAN IS logged.