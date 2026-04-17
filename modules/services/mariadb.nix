{
  pkgs,
  allAddresses,
  config,
  ...
}:

let
  host = config.networking.hostName;
in
{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ ];
    ensureUsers = [ ];

    settings = {
      mysqld = {
        bind-address = allAddresses.hosts.${host}.network.lan.ipv4.host;
      };
    };
  };
}
