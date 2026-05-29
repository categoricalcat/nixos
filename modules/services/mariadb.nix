{
  pkgs,
  ...
}:

{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ ];
    ensureUsers = [ ];

    settings = {
      mysqld = {
        bind-address = "0.0.0.0";
      };
    };
  };
}
