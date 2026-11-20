{
  addresses,
  allAddresses,
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (allAddresses) monitoring;
  monitoringLib = import ./lib.nix;
  hostName = config.networking.hostName;
  isCentral = hostName == monitoring.centralHost;
  listenAddress = monitoringLib.exporterAddress allAddresses hostName;
  exporterMetadata = monitoring.exporters;

  serviceAvailable =
    name:
    if name == "nginx" then
      config.services.nginx.enable
    else if name == "fail2ban" then
      config.services.fail2ban.enable
    else if name == "postgres" then
      config.services.postgresql.enable
    else if name == "adguard" then
      config.services.adguardhome.enable
    else if name == "unbound" then
      config.services.unbound.enable
    else if name == "redis" then
      config.services.redis.servers ? "" && config.services.redis.servers."".enable
    else
      true;

  enabledHere =
    name: spec:
    serviceAvailable name && lib.elem hostName (monitoringLib.resolveHosts monitoring spec.hosts);

  enabledExporters = lib.filterAttrs enabledHere exporterMetadata;

  # Ping every peer except this host itself, over the families that have a
  # path (internet v6 only once `ipv6Egress` is true).
  smokepingPeers = builtins.filter (peer: peer.name != hostName) monitoring.probePeers;
  smokepingHosts =
    map (peer: peer.v4) smokepingPeers
    ++ map (peer: peer.v6) (
      builtins.filter (
        peer: peer ? v6 && (monitoring.ipv6Egress || peer.scope != "internet")
      ) smokepingPeers
    );

  mkExporter =
    name: spec:
    {
      enable = true;
      openFirewall = false;
    }
    // (spec.settings or { })
    // lib.optionalAttrs (name == "postgres") {
      # Postgres is socket-only with peer auth, so scrape through the socket
      # as the local postgres superuser instead of TCP with a password.
      runAsLocalSuperUser = true;
      dataSourceName = "postgresql:///postgres?host=${(monitoringLib.getCentralHost allAddresses).services.postgresql.socketDir}";
    }
    // lib.optionalAttrs (name == "smokeping") { hosts = smokepingHosts; }
    // (if name == "fail2ban" then { host = listenAddress; } else { inherit listenAddress; });
in
{
  imports = [ ./adguard-exporter ];

  services = {
    nginx.statusPage = lib.mkIf (enabledHere "nginx" exporterMetadata.nginx) true;

    prometheus.exporters = lib.mapAttrs mkExporter enabledExporters;
  };

  # Exporters on non-central hosts answer the central scraper only (interim
  # source rule until mTLS Tier 3 replaces it with client certificates).
  networking.firewall.extraInputRules = lib.mkIf (!isCentral) (
    let
      centralLan = (monitoringLib.getCentralHost allAddresses).network.lan.ipv4.host;
      exporterPorts = lib.concatMapStringsSep ", " (
        name: toString config.services.prometheus.exporters.${name}.port
      ) (lib.attrNames enabledExporters);
    in
    ''
      iifname "${addresses.network.lan.interface}" ip saddr ${centralLan} tcp dport { ${exporterPorts} } accept comment "exporters scraped by central host only"
    ''
  );

  # pro-bing drops a target forever when its first sendmsg returns ENETUNREACH.
  # network-online is LAN-only on the scrape hosts, so fail the start until an
  # IPv4 default route exists and let Restart= try again. `+` runs the check
  # outside RestrictAddressFamilies (ip uses netlink).
  systemd.services = lib.mkIf (enabledHere "smokeping" exporterMetadata.smokeping) {
    prometheus-smokeping-exporter = monitoringLib.mkWantsAfter [ "network-online.target" ] // {
      serviceConfig = {
        RestartSec = "5s";
        ExecStartPre = "+${pkgs.writeShellScript "smokeping-require-default-route" ''
          ${lib.getExe' pkgs.iproute2 "ip"} -4 route show default | ${lib.getExe' pkgs.gnugrep "grep"} -q '^default '
        ''}";
      };
    };
  };
}
