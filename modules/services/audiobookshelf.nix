{
  config,
  allAddresses,
  ...
}:

let
  addrs = allAddresses.hosts.${config.networking.hostName};
in
{
  services.audiobookshelf = {
    enable = true;
    host = "0.0.0.0";
    inherit (addrs.services.audiobookshelf) port;
  };

  users.users.audiobookshelf.extraGroups = [ "media" ];

  systemd.tmpfiles.rules = [
    "d /persist/media/podcasts 2775 root media - -"
  ];

  systemd.services.audiobookshelf.serviceConfig.UMask = "0002";
}
