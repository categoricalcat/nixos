{ config, lib, ... }:
{
  services.resolved = {
    enable = true;  # Enable systemd-resolved for DNS resolution
    dnssec = "false";  # Disable DNSSEC to avoid potential issues
    domains = [ "~." ];  # Handle all domains
    fallbackDns = [ "8.8.8.8" "1.1.1.1" ];  # Fallback DNS servers
    extraConfig = ''
      MulticastDNS=yes
      DNSStubListenerExtra=172.17.0.1
    '';
  };
  
  services.avahi = {
    enable = true;  # For zero-config service discovery
    nssmdns4 = true;  # So apps can find .local hostnames
    nssmdns6 = true;  # Same for IPv6
    reflector = true;  # Share services between VPN and LAN

    publish = {
      enable = true;  # Let others discover our services
      addresses = true;  # Share our IP for direct connections
      workstation = true;  # Show up in network browsers
      domain = true;  # Advertise our .local domain
      userServices = true;  # Allow user-level service sharing
    };

    allowInterfaces = [
      "wg0"    # Share services over VPN
      "bond0"  # Share on local network
    ];

    extraServiceFiles = {  # Services to advertise
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
          <name replace-wildcards="yes">%h HTTP Server</name>
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

      web_3000 = ''
        <?xml version="1.0" standalone='no'?>
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h 3000 Server</name>
          <service>
            <type>_http._tcp</type>
            <port>3000</port>
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
}