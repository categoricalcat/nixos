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

    -- Primary: AdGuardHome on port 5353. Lazy checks let regular query
    -- failures mark it down, so fallbacks are used when local DNS is sick.
    newServer({address="127.0.0.1:5353", order=1,
               checkTimeout=1000, maxCheckFailures=2, rise=2,
               checkInterval=1, name="adguard-local",
               healthCheckMode="lazy", lazyHealthCheckThreshold=30,
               lazyHealthCheckSampleSize=20, lazyHealthCheckMinSampleCount=5,
               lazyHealthCheckFailedInterval=5})

    -- Fallback: public resolvers in a separate pool for explicit retries.
    ${lib.concatMapStringsSep "\n" (server: ''
      newServer({address="${server}", pool="fallback", order=1,
                 checkTimeout=1000, maxCheckFailures=3, rise=1,
                 checkInterval=5, name="fallback-${lib.strings.sanitizeDerivationName server}"})
    '') fallbackServers}

    setServerPolicy(firstAvailable)
    setPoolServerPolicy(firstAvailable, "fallback")
    setServFailWhenNoServer(true)

    function makeQueryRestartable(dq)
      dq:setRestartable()
      return DNSAction.None
    end

    function retryLocalFailureOnFallback(dr)
      if dr.pool ~= "fallback" and dr:getRestartCount() == 0 and (dr.rcode == 2 or dr.rcode == 5) then
        dr.pool = "fallback"
        dr:restart()
      end
      return DNSResponseAction.None
    end

    addAction(AllRule(), LuaAction(makeQueryRestartable))
    addAction(PoolAvailableRule(""), PoolAction(""))
    addAction(AllRule(), PoolAction("fallback"))
    addResponseAction(AllRule(), LuaResponseAction(retryLocalFailureOnFallback))

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
      ExecStartPre = "${pkgs.dnsdist}/bin/dnsdist --check-config -C ${configFile}";
      ExecStart = "${pkgs.dnsdist}/bin/dnsdist --supervised --disable-syslog -C ${configFile}";
      Restart = "on-failure";
      RestartSec = "2";
      Type = "notify";
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
