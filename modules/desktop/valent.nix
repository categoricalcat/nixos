{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = {
    environment.systemPackages = [
      pkgs.valent
    ]
    ++ lib.optionals (config.desktop.environment == "gnome") [
      pkgs.gnomeExtensions.valent
    ];

    # KDE Connect protocol — phone discovery (UDP) + data transfer (TCP)
    networking.firewall = {
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
    };
  };
}
