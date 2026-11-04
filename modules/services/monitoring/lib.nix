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

  exporterAddress =
    allAddresses: hostName:
    if hostName == allAddresses.monitoring.centralHost then
      "127.0.0.1"
    else
      allAddresses.hosts.${hostName}.network.lan.ipv4.host;

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

  lanHttpEndpoint = host: service: "http://${host.network.lan.ipv4.host}:${toString service.port}";
in
{
  inherit
    exporterAddress
    getCentralHost
    hostRelabelConfig
    lanHttpEndpoint
    mkCentralHostAssertion
    mkWantsAfter
    resolveHosts
    ;
}
