{ allAddresses, pkgs, ... }:

let
  postgres = allAddresses.hosts.yifuwuqi.services.postgresql;
  package = pkgs.${postgres.packageAttr};
  schema = package.psqlSchema;
  dataDir = "${postgres.dataRoot}/${schema}";
  databaseNames = builtins.attrValues postgres.databases;
in
{
  services.postgresql = {
    enable = true;
    inherit package;
    inherit dataDir;
    ensureDatabases = databaseNames;
    ensureUsers =
      map (name: {
        inherit name;
        ensureDBOwnership = true;
      }) databaseNames
      ++ [
        {
          name = "yi";
          ensureDBOwnership = false;
          ensureClauses.superuser = true;
        }
      ];

    enableTCPIP = true;
    authentication = ''
      # type database DBuser auth-method
      host   all      all    ${allAddresses.hosts.yifuwuqi.network.vpn.ipv4.cidr} trust
      host   all      all    127.0.0.1/32 trust
    '';
  };

  networking.firewall.allowedTCPPorts = [ 5432 ];

  systemd.tmpfiles.rules = [
    "d ${postgres.dataRoot} 0750 postgres postgres -"
    "d ${dataDir} 0750 postgres postgres -"
  ];
}
