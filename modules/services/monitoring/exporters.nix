{
  addresses,
  allAddresses,
  config,
  lib,
  ...
}:

let
  inherit (allAddresses) monitoring;
  hostName = config.networking.hostName;
  isCentral = hostName == monitoring.centralHost;
  listenAddress = if isCentral then "127.0.0.1" else addresses.network.lan.ipv4.host;
  exporterMetadata = monitoring.exporters;

  resolveHosts =
    selector:
    if builtins.isList selector then
      selector
    else if selector == "centralHost" then
      [ monitoring.centralHost ]
    else if selector == "proxyHost" then
      [ monitoring.proxyHost ]
    else
      monitoring.${selector};

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

  enabledHere = name: spec: serviceAvailable name && lib.elem hostName (resolveHosts spec.hosts);

  enabledExporters = lib.filterAttrs enabledHere exporterMetadata;

  mkExporter =
    name: spec:
    {
      enable = true;
      openFirewall = false;
    }
    // (spec.settings or { })
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
}
