# Network Access Configuration Plan for fufuwuqi

## Objective
Configure dual DNS resolution system:
- **Avahi (mDNS)**: Handle `fufuwuqi.local` for zero-configuration local network access
- **dnsmasq**: Handle `fufuwuqi.vpn` for WireGuard VPN clients with full port access

## Current Infrastructure
- **Hostname:** fufuwuqi
- **Network:** Bond interface (bond0) with DHCP
- **VPN:** WireGuard on wg0 (10.100.0.1/28)
- **Firewall:** wg0 is trusted interface (all ports accessible)
- **Existing Services:** Avahi enabled, WireGuard configured

## Implementation Plan

### Phase 1: Avahi Configuration for Local Network

#### 1.1 Service Definitions
Create service advertisements for all running services:

```nix
# modules/services.nix additions
services.avahi = {
  enable = true;  # Already enabled
  nssmdns4 = true;
  nssmdns6 = true;
  reflector = true;
  
  publish = {
    enable = true;
    addresses = true;
    workstation = true;
    domain = true;
    userServices = true;
  };
  
  allowInterfaces = [ "wg0" "bond0" ];
  
  extraServiceFiles = {
    ssh = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h SSH</name>
        <service>
          <type>_ssh._tcp</type>
          <port>24212</port>
        </service>
      </service-group>
    '';
    
    web = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h Web</name>
        <service>
          <type>_http._tcp</type>
          <port>80</port>
        </service>
        <service>
          <type>_https._tcp</type>
          <port>443</port>
        </service>
      </service-group>
    '';
    
    cockpit = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h Cockpit</name>
        <service>
          <type>_cockpit._tcp</type>
          <port>9090</port>
        </service>
      </service-group>
    '';
    
    minecraft = ''
      <?xml version="1.0" standalone='no'?>
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h Minecraft</name>
        <service>
          <type>_minecraft._tcp</type>
          <port>25565</port>
        </service>
      </service-group>
    '';
  };
};
```

### Phase 2: dnsmasq Configuration for VPN

#### 2.1 Create VPN DNS Module
```nix
# Create modules/vpn-dns.nix
{ config, pkgs, ... }:
{
  services.dnsmasq = {
    enable = true;
    settings = {
      # Listen only on WireGuard interface
      interface = [ "wg0" ];
      bind-interfaces = true;
      listen-address = [ "10.100.0.1" ];
      
      # Disable DNS forwarding for local queries
      no-resolv = true;
      
      # Upstream DNS servers
      server = [ "1.1.1.1" "8.8.8.8" ];
      
      # Define VPN domain
      domain = "vpn";
      local = "/vpn/";
      
      # Static DNS entry for the server
      address = "/fufuwuqi.vpn/10.100.0.1";
      
      # Performance settings
      cache-size = 1000;
      
      # Logging (disable after testing)
      log-queries = true;
      log-facility = "/var/log/dnsmasq-vpn.log";
    };
  };
  
  # DNS already allowed on wg0 via trusted interface
}
```

#### 2.2 Import Module
```nix
# Add to configuration.nix imports
imports = [
  # ... existing imports ...
  ./modules/vpn-dns.nix
];
```

### Phase 3: Client Configuration Updates

#### 3.1 WireGuard Client Configuration Template
Update all WireGuard clients to use the VPN DNS:

```ini
[Interface]
PrivateKey = <client-private-key>
Address = 10.100.0.X/32  # X = 2 for macOS, 3 for Windows
DNS = 10.100.0.1

[Peer]
PublicKey = <server-public-key>
Endpoint = <server-public-ip>:51820
AllowedIPs = 10.100.0.0/28
PersistentKeepalive = 25
```

### Phase 4: Testing Protocol

#### 4.1 Local Network Tests
```bash
# Test mDNS resolution
ping fufuwuqi.local

# Verify service discovery
avahi-browse -art | grep fufuwuqi

# Test from different platforms
# macOS: dns-sd -B _services._dns-sd._udp
# Windows: ping fufuwuqi.local
# Linux: avahi-resolve -n fufuwuqi.local
```

#### 4.2 VPN Tests
```bash
# After connecting to VPN
# Test DNS resolution
nslookup fufuwuqi.vpn 10.100.0.1
dig @10.100.0.1 fufuwuqi.vpn

# Verify connectivity
ping fufuwuqi.vpn

# Confirm all ports accessible (wg0 is trusted)
nmap -p- fufuwuqi.vpn
```

### Phase 5: Maintenance

#### 5.1 Monitoring Commands
```bash
# Monitor Avahi
systemctl status avahi-daemon
journalctl -u avahi-daemon -f

# Monitor dnsmasq
systemctl status dnsmasq
tail -f /var/log/dnsmasq-vpn.log

# Check DNS resolution
dig @10.100.0.1 fufuwuqi.vpn
avahi-resolve -n fufuwuqi.local
```

#### 5.2 Disable Logging After Testing
```nix
# In modules/vpn-dns.nix, comment out or remove:
# log-queries = true;
# log-facility = "/var/log/dnsmasq-vpn.log";
```

## Expected Outcomes

1. **Local Network Access**
   - Any device on the local network can access the server via `fufuwuqi.local`
   - Zero configuration required on clients
   - Service discovery works automatically

2. **VPN Access**
   - VPN clients can access the server via `fufuwuqi.vpn`
   - All server ports are accessible (wg0 is trusted interface)
   - DNS queries are resolved by the server

## Configuration Files Summary

1. **modules/services.nix** - Enhanced Avahi service definitions
2. **modules/vpn-dns.nix** - New dnsmasq configuration for VPN
3. **configuration.nix** - Import vpn-dns.nix module
4. **Client WireGuard configs** - Add DNS = 10.100.0.1