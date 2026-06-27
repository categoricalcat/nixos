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
    ensureUsers = map (name: {
      inherit name;
      ensureDBOwnership = true;
    }) databaseNames;
  };

  systemd.tmpfiles.rules = [
    "d ${postgres.dataRoot} 0750 postgres postgres -"
    "d ${dataDir} 0750 postgres postgres -"
  ];
}
