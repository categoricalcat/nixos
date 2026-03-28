{ config, lib, ... }:

with lib;

let
  cfg = config.security.fido2;
in
{
  options.security.fido2 = {
    enable = mkEnableOption "FIDO2/U2F authentication";
  };

  config = mkIf cfg.enable {
    security.pam.u2f = {
      enable = true;
      settings = {
        cue = true;
        interactive = true;
      };
    };

    security.pam.services = {
      login.u2fAuth = true;
      sudo.u2fAuth = true;
    };
  };
}
