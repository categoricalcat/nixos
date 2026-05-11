{
  addresses,
  lib,
  pkgs,
  ...
}:

let
  fallbackServers = addresses.dns.fallbackServers or [ "9.9.9.9:53" ];
  configFile = pkgs.writeText "dnsdist.conf" ''
    setLocal("0.0.0.0:53")
    addLocal("[::]:53")
    setACL({"0.0.0.0/0", "::/0"})
    setVerbose(false)

    -- Primary: AdGuardHome on port 5353, checked every 1s
    newServer({address="127.0.0.1:5353", order=1,
               checkTimeout=1000, maxCheckFailures=3, rise=2,
               checkInterval=1, name="adguard-local"})

    -- Fallback: public resolvers (only when AdGuardHome is fully down)
    ${lib.concatMapStringsSep "\n" (server: ''
      newServer({address="${server}", order=2,
                 checkTimeout=1000, maxCheckFailures=3, rise=1,
                 checkInterval=5, name="fallback-${lib.strings.sanitizeDerivationName server}"})
    '') fallbackServers}

    setServerPolicy(firstAvailable)

    -- Rate-limit health-check logs
    setStaleCacheEntriesTTL(10)
  '';
in
{
  environment.systemPackages = [ pkgs.dnsdist ];

  systemd.services.dnsdist = {
    description = "dnsdist DNS proxy — health-checked AdGuardHome frontend";
    after = [
      "network.target"
      "adguardhome.service"
    ];
    wants = [
      "network.target"
      "adguardhome.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.dnsdist}/bin/dnsdist --supervised -C ${configFile}";
      Restart = "always";
      RestartSec = "2";
      Type = "notify";
      WatchdogSec = "10";
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      StateDirectory = "dnsdist";
    };
  };

  services.adguardhome.settings.dns.port = lib.mkForce 5353;
}
