{
  allAddresses,
  config,
  lib,
  systemdHardening,
  ...
}:

let
  monitoringLib = import ./lib.nix;
  hostName = config.networking.hostName;
  centralHost = monitoringLib.getCentralHost allAddresses;
  mtls = config.yi.mtls;

  # Loki binds loopback, so the ingress is its only reachable front door even
  # with mTLS off; only the scheme changes then.
  scheme = if mtls.enable then "https" else "http";
  endpoint = "${scheme}://${monitoringLib.ingressAddress centralHost}/loki";
in
{
  imports = [ ../mtls.nix ];

  services.vector = {
    enable = true;
    journaldAccess = true;

    settings = {
      sources.journald.type = "journald";

      transforms.enrich_journal = {
        type = "remap";
        inputs = [ "journald" ];
        source = ''
          unit = string(._SYSTEMD_UNIT) ?? ""
          if unit == "" {
            unit = string(.SYSLOG_IDENTIFIER) ?? ""
          }
          if unit == "" {
            unit = "system"
          }
          .unit = unit
        '';
      };

      sinks.loki = {
        type = "loki";
        inputs = [ "enrich_journal" ];
        inherit endpoint;
        labels = {
          host = hostName;
          job = "systemd-journal";
          unit = "{{ unit }}";
        };
        encoding.codec = "text";
      }
      // lib.optionalAttrs mtls.enable {
        tls = {
          ca_file = mtls.caFile;
          crt_file = mtls.clientCert;
          key_file = mtls.clientKey;
        };
      };
    };
  };

  systemd.services.vector.serviceConfig = systemdHardening // {
    # Vector here only reads the journal and pushes to Loki; the nixpkgs
    # default grant is for configs that bind privileged ports.
    AmbientCapabilities = lib.mkForce "";
  };
}
