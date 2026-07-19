_:

{
  services.unbound = {
    enable = true;

    # Enable the control socket so we can use `unbound-control`
    localControlSocketPath = "/run/unbound/unbound.ctl";
    settings = {
      server = {
        # Listen on localhost on a non-standard port to avoid conflicting with AdGuard Home
        interface = [ "127.0.0.1" ];
        port = 5335;

        # Only allow queries from localhost
        access-control = [ "127.0.0.0/8 allow" ];

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
