{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  unstable = import ../nixpkgs-unstable.nix { inherit inputs pkgs; };
  tomlFormat = pkgs.formats.toml { };
  cfg = config.services.lan-mouse;
in
{
  options.services.lan-mouse = {
    settings = lib.mkOption {
      inherit (tomlFormat) type;
      default = { };
      description = "lan-mouse configuration settings";
    };
  };

  config = lib.mkIf (cfg.settings != { }) {
    networking.firewall.interfaces."tailscale0" = {
      allowedTCPPorts = [ 4242 ];
      allowedUDPPorts = [ 4242 ];
    };

    home-manager.users.yi = {
      home.packages = [ unstable.lan-mouse ];

      xdg.configFile."lan-mouse/config.toml".source = tomlFormat.generate "lan-mouse-config" (
        lib.recursiveUpdate { port = 4242; } cfg.settings
      );

      systemd.user.services.lan-mouse = {
        Unit = {
          Description = "lan-mouse daemon";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${unstable.lan-mouse}/bin/lan-mouse daemon";
          Restart = "on-failure";
          RestartSec = 5;
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
  };
}
