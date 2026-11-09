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

    # Socket-only with the nixpkgs default pg_hba: peer on the unix socket,
    # md5 on loopback TCP. No network trust entries; remote administration
    # goes through SSH on yifuwuqi, not a database listener.
  };

  systemd.tmpfiles.rules = [
    "d ${postgres.dataRoot} 0750 postgres postgres -"
    "d ${dataDir} 0750 postgres postgres -"
  ];
}
