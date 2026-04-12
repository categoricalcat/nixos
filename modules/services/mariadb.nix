{ pkgs, ... }:

{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ ];
    ensureUsers = [ ];

    settings = {
      mysqld = {
        bind-address = "10.100.0.1";
      };
    };
  };
}
