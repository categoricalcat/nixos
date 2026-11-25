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
    # Decouple database collations from glibc (version stays 1 across OS
    # upgrades, avoiding template1 collation mismatch on CREATE DATABASE and
    # index invalidation) while keeping UTF-8 and Unicode ctype.
    initdbArgs = [
      "--encoding=UTF8"
      "--locale=C"
      "--locale-provider=builtin"
      "--builtin-locale=C.UTF-8"
    ];
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

  # Socket-only with md5 on loopback; the cgroup filter is a second layer
  # behind the missing TCP listener.
  systemd.services.postgresql.serviceConfig.IPAddressAllow = [ "localhost" ];
}
