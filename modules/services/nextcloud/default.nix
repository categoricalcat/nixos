{
  config,
  pkgs,
  inputs,
  allAddresses,
  ...
}:

let
  unstable = import ../../nixpkgs-unstable.nix { inherit inputs pkgs; };
in
{
  services.nextcloud = {
    enable = true;
    package = unstable.nextcloud33;
    hostName = "${config.networking.hostName}.yun";
    home = "/srv/nextcloud";

    database.createLocally = true;
    configureRedis = true;

    maxUploadSize = "10G";

    config = {
      dbtype = "mysql";
      adminuser = "admin";
      adminpassFile = config.sops.secrets."passwords/nextcloud".path;
    };

    settings = {
      trusted_domains = [
        "${allAddresses.hosts.yifuwuqi.network.lan.ipv4.host}"
      ];
    };
  };

  sops.secrets."passwords/nextcloud" = {
    owner = "nextcloud";
    group = "nextcloud";
  };
}
