# Unbound + AdGuard Home Integration Plan

This document outlines the steps to integrate Unbound as the recursive upstream DNS resolver for the existing AdGuard Home setup.

## Current Architecture

Currently, AdGuard Home acts as a DNS sinkhole and forwards unblocked queries to a large parallel list of public DNS servers (Quad9, Google, Cloudflare, etc.).

## Target Architecture

The goal is to route all unblocked queries from AdGuard Home to a local Unbound instance. Unbound will then recursively resolve the queries directly from the root DNS servers, improving privacy by eliminating third-party corporate DNS providers.

**Flow:** `Client -> AdGuard Home (Port 53) -> Unbound (Port 5335) -> Authoritative Servers`

## Implementation Steps

### 1. Create the Unbound Module

Create a new NixOS module file at `modules/services/unbound.nix` with the following configuration:

```nix
{ config, pkgs, ... }:

{
  services.unbound = {
    enable = true;
    settings = {
      server = {
        # Listen on localhost on a non-standard port to avoid conflicting with AdGuard Home
        interface = [ "127.0.0.1" ];
        port = 5335;
        
        # Only allow queries from localhost
        access-control = [ "127.0.0.0/8 allow" ];
        
        # Enable DNSSEC validation
        auto-trust-anchor-file = "/var/lib/unbound/root.key";
        
        # Performance tuning and caching
        cache-min-ttl = 300;
        cache-max-ttl = 86400;
        prefetch = "yes";
        serve-expired = "yes";
        
        # Privacy settings
        hide-identity = "yes";
        hide-version = "yes";
        qname-minimisation = "yes";
      };
    };
  };
}
```

### 2. Update AdGuard Home Configuration

Edit `modules/services/adguardhome.nix` to change its upstream servers.

**Change this:**

```nix
        upstream_dns =
          addresses.dns.quad9
          ++ addresses.dns.adguard
          ++ addresses.dns.google
          ++ addresses.dns.cloudflare
          ++ addresses.dns.opendns
          ++ addresses.dns.nextdns
          ++ addresses.dns.freedns;
```

**To this:**

```nix
        # Forward everything to local Unbound
        upstream_dns = [ "127.0.0.1:5335" ];
```

*Note: You may optionally want to change `upstream_mode` from `"parallel"` to `"load_balance"` or `"fastest_addr"` if you only have one upstream, although it shouldn't cause issues if left as is.*

### 3. Enable Unbound on the Hosts

AdGuard Home is currently used on `yirukou` and `yifuwuqi`. You will need to add the new Unbound module to the `services.nix` files for those hosts so they both run Unbound alongside AdGuard.

Add `../../modules/services/unbound.nix` to the imports list in:

- `hosts/yirukou/services.nix`
- `hosts/yifuwuqi/services.nix`

### 4. Deploy

Apply the NixOS configuration. Once applied, you can verify it's working by querying AdGuard Home from a client and seeing the requests show up as answered by `127.0.0.1:5335` (Unbound) in the AdGuard Home query log.

### 5. Router & Client Impact (e.g. `yirukou`)

Because Unbound sits *behind* AdGuard Home and listens on a local loopback port (`127.0.0.1:5335`), this architecture is completely invisible to your network clients.

- You do **not** need to change your Kea DHCP scope configuration on `yirukou`.
- DHCP will continue handing out `10.42.0.1` and `10.42.0.2` as the DNS servers to clients on the LAN and VLAN 42.
- The firewall and NAT rules on `yirukou` do not need any updates because port 53 traffic is still being handled by AdGuard Home, exactly as before.

### 6. Alternative: TP-Link ER706W (Omada) Router

If you deploy this on a network managed by a TP-Link ER706W router instead of `yirukou`, the principle remains identical. The ER706W doesn't need to know about Unbound.

**How to point the ER706W to AdGuard Home:**

- **In Standalone Mode:**
  1. Log into the ER706W web interface.
  2. Go to **Network** -> **LAN** -> **DHCP Server** (or the specific VLAN/Network you are configuring).
  3. Change the **Primary DNS Server** to the local IP address of your AdGuard Home machine.
  4. Leave the Secondary DNS empty (or point to a fallback AdGuard).
- **In Omada Controller Mode:**
  1. Open your Omada SDN Controller.
  2. Go to **Settings** -> **Wired Networks** -> **LAN**.
  3. Edit your LAN network and expand the **Advanced/DHCP** settings.
  4. Set the **DNS Server** to Manual and input the local IP of your AdGuard Home machine.

In both cases, the router will use DHCP to tell your phones/laptops to use AdGuard. AdGuard then secretly forwards those requests to Unbound running locally on its loopback port.

## Concepts & FAQ

### How does Unbound work? How is it different from AdGuard Home?

They serve two completely different purposes in this network stack:

- **AdGuard Home is a DNS Sinkhole/Forwarder:** Its primary job is filtering. It receives a query, checks it against blocklists, and drops it if it's an ad or tracker. If the domain is legitimate, AdGuard doesn't actually resolve it itself—it forwards it to an upstream provider.
- **Unbound is a Recursive Resolver:** It doesn't block anything. Its only job is to find the true IP address of a domain from the global root servers.

Unbound comes pre-packaged with a list of "Root Hints" (the IP addresses of the 13 logical Root DNS Servers that power the internet). When AdGuard asks Unbound for an IP (e.g., `github.com`), Unbound performs a "recursive" lookup:

1. **Root Server:** Unbound asks a Root Server: "I need the IP for `github.com`." The Root replies with the IPs for the `.com` Top-Level Domain (TLD) servers.
2. **TLD Server:** Unbound asks the `.com` server: "I need the IP for `github.com`." The TLD server replies with the specific authoritative servers that GitHub owns.
3. **Authoritative Server:** Finally, Unbound asks GitHub's authoritative server for the actual IP address, and returns it to AdGuard.

### Will the "multiple DNS schema" be ported?

**No.** The current AdGuard Home setup uses a parallel schema (querying Quad9, Google, Cloudflare, etc., simultaneously and using the fastest response).

The entire purpose of introducing Unbound is to eliminate the need for these third-party corporate providers for privacy reasons. The long list of public upstreams in AdGuard Home will be replaced with a single local upstream: `[ "127.0.0.1:5335" ]`. Unbound will then handle finding the IPs directly from the root servers.

### Will this be faster?

For daily browsing, the speed difference will be practically unnoticeable, but technically:

- **Cold Cache (First visit to a new site): Slower.** Parallel public queries are faster because massive providers like Google have enormous shared caches. Unbound has to perform the full 3-step recursive lookup, which can take 50-300ms depending on the authoritative server's distance.
- **Warm Cache (Repeat visits): Instant.** Once Unbound finds an IP, it caches it locally. Subsequent requests return the IP instantly (<1ms).
- **Prefetching:** The Unbound config includes `prefetch = "yes"`. If an item in the cache is about to expire and is requested, Unbound returns the old cached IP immediately so the user doesn't wait, and goes to fetch the fresh IP in the background.

This setup trades a tiny fraction of a second on initial, un-cached page loads for complete DNS privacy.
