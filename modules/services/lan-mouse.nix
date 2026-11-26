{
  config,
  pkgs,
  lib,
  ...
}:

let
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
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to start the lan-mouse daemon automatically with the graphical session.";
    };
  };

  config = lib.mkIf (cfg.settings != { }) {
    # A trusted interface is accepted wholesale by nixpkgs' `input` chain
    # before `input-allow` is consulted, so a port list on one enforces
    # nothing and only reads as a scope. Client-mode hosts trust
    # `tailscale0`; a server-mode host does not and needs the rule.
    networking.firewall.interfaces =
      lib.mkIf
        (!lib.elem config.services.tailscale.interfaceName config.networking.firewall.trustedInterfaces)
        {
          ${config.services.tailscale.interfaceName} = lib.mkIf config.services.tailscale.enable {
            allowedTCPPorts = [ 4242 ];
            allowedUDPPorts = [ 4242 ];
          };
        };

    home-manager.users.yi = {
      home.packages = [ pkgs.lan-mouse ];

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
          ExecStart = "${pkgs.lan-mouse}/bin/lan-mouse daemon";
          Restart = "on-failure";
          RestartSec = 5;
        };

        Install = lib.mkIf cfg.autostart {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
  };
}
