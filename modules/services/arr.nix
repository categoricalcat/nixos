{
  config,
  lib,
  allAddresses,
  ...
}:

let
  inherit (config.networking) hostName;
  addrs = allAddresses.hosts.${hostName};
in
{
  users.groups.media = { };

  systemd.tmpfiles.rules = [
    "d /persist/media 2775 root media - -"
    "d /persist/media/downloads 2775 root media - -"
    "d /persist/media/downloads/incomplete 2775 root media - -"
    "d /persist/media/downloads/complete 2775 root media - -"
    "d /persist/media/movies 2775 root media - -"
    "d /persist/media/tv 2775 root media - -"
    "d /persist/media/music 2775 root media - -"
    "d /persist/media/books 2775 root media - -"
  ];

  services = {
    radarr = {
      enable = true;
      group = "media";
    };
    sonarr = {
      enable = true;
      group = "media";
    };
    lidarr = {
      enable = true;
      group = "media";
    };
    readarr = {
      enable = true;
      group = "media";
    };
    bazarr = {
      enable = true;
      group = "media";
      listenPort = addrs.services.bazarr.port;
    };
    prowlarr = {
      enable = true;
    };
  };

  systemd.services = {
    radarr = {
      environment.RADARR__SERVER__PORT = toString addrs.services.radarr.port;
      serviceConfig = {
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    sonarr = {
      environment.SONARR__SERVER__PORT = toString addrs.services.sonarr.port;
      serviceConfig = {
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    lidarr = {
      environment.LIDARR__SERVER__PORT = toString addrs.services.lidarr.port;
      serviceConfig = {
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    readarr = {
      environment.READARR__SERVER__PORT = toString addrs.services.readarr.port;
      serviceConfig = {
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    bazarr = {
      serviceConfig = {
        UMask = lib.mkForce "0002";
        PrivateUsers = lib.mkForce "identity";
        ReadWritePaths = [ "/persist/media" ];
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
    prowlarr = {
      environment.PROWLARR__SERVER__PORT = toString addrs.services.prowlarr.port;
      serviceConfig = {
        IPAddressDeny = lib.mkForce [ ];
        IPAddressAllow = lib.mkForce [ ];
      };
    };
  };
}
