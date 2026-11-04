{
  addresses,
  allAddresses,
  config,
  lib,
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
    // lib.optionalAttrs (name == "smokeping") { hosts = smokepingHosts; }
    // (if name == "fail2ban" then { host = listenAddress; } else { inherit listenAddress; });
in
{
  services = {
    nginx.statusPage = lib.mkIf (enabledHere "nginx" exporterMetadata.nginx) true;

    prometheus.exporters = lib.mapAttrs mkExporter enabledExporters;
  };

  networking.firewall.interfaces.${addresses.network.lan.interface}.allowedTCPPorts =
    lib.mkIf (!isCentral)
      (lib.mapAttrsToList (name: _: config.services.prometheus.exporters.${name}.port) enabledExporters);

  systemd.services = lib.mkMerge [
    (lib.mkIf (!isCentral) (
      lib.mapAttrs' (
        name: _:
        lib.nameValuePair "prometheus-${name}-exporter" {
          serviceConfig.FreeBind = true;
        }
      ) enabledExporters
    ))
    (lib.mkIf (enabledHere "smokeping" exporterMetadata.smokeping) {
      prometheus-smokeping-exporter = monitoringLib.mkWantsAfter [ "network-online.target" ];
    })
  ];
}
