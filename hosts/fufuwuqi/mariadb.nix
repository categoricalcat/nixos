{ pkgs, ... }:

{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ "joplin" ];
    ensureUsers = [
      {
        name = "joplin";
        ensurePermissions = {
          "joplin.*" = "ALL PRIVILEGES";
        };
      }
    ];

    settings = {
      mysqld = {
        bind-address = "10.100.0.1";
      };
    };
  };
}
