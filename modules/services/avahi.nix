{ addresses, ... }:
{

  services.avahi = {
    enable = true; # For zero-config service discovery
    nssmdns4 = true; # So apps can find .local hostnames
    nssmdns6 = true; # Same for IPv6
    openFirewall = true; # "safe" up to LAN

    settings = {
      server.allow-interfaces = [
        # "tailscale0"
        "wt0"
        "eno1"
      ];
      reflector.enable-reflector = true; # Share services between VPN and LAN
      publish = {
        disable-publishing = false; # Let others discover our services
        disable-user-service-publishing = false; # Allow user-level service sharing
        publish-addresses = true; # Share our IP for direct connections
        publish-workstation = true; # Show up in network browsers
        publish-domain = true; # Advertise our .local domain
      };
    };

    extraServiceFiles = {
      # Services to advertise
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

      cockpit = ''
        <?xml version="1.0" standalone='no'?>
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h Cockpit</name>
          <service>
            <type>_cockpit._tcp</type>
            <port>${toString addresses.services.cockpit.port}</port>
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
