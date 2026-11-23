let
  resolveHosts =
    monitoring: selector:
    if builtins.isList selector then
      selector
    else if selector == "centralHost" then
      [ monitoring.centralHost ]
    else if selector == "proxyHost" then
      [ monitoring.proxyHost ]
    else
      monitoring.${selector};

  getCentralHost = allAddresses: allAddresses.hosts.${allAddresses.monitoring.centralHost};

  hostRelabelConfig = [
    {
      source_labels = [ "host" ];
      target_label = "instance";
    }
  ];

  mkCentralHostAssertion =
    {
      modulePath,
      monitoring,
      hostName,
    }:
    {
      assertion = hostName == monitoring.centralHost;
      message = "${modulePath}: may only be imported on ${monitoring.centralHost}";
    };

  mkWantsAfter = units: {
    wants = units;
    after = units;
  };

  # The machine paths ride each host's mTLS ingress; no exporter or Loki port
  # is ever dialled directly.
  ingressAddress = host: "${host.network.lan.ipv4.host}:${toString host.services.ingress.port}";
in
{
  inherit
    getCentralHost
    hostRelabelConfig
    ingressAddress
    mkCentralHostAssertion
    mkWantsAfter
    resolveHosts
    ;
}
