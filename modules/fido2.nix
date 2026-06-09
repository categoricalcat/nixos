{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.security.fido2;
in
{
  options.security.fido2 = {
    enable = mkEnableOption "FIDO2/U2F authentication";
  };

  config = mkIf cfg.enable {
    users.groups.plugdev = { };
    security = {
      pam = {
        u2f = {
          enable = true;
          settings = {
            cue = true;
            interactive = true;
          };
        };

        services = {
          login.u2fAuth = true;
          sudo.u2fAuth = true;
        };
      };
    };

    services.udev.packages = [ pkgs.libfido2 ];
    environment.systemPackages = [ pkgs.libfido2 ];
  };
}
