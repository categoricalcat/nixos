{ config, lib, ... }:

{
  options.services.nix-access-tokens.enable = lib.mkEnableOption "GitHub access tokens for Nix";

  config = {
    sops.secrets = lib.optionalAttrs config.services.nix-access-tokens.enable {
      "github-token" = {
        mode = "0440";
      };
    };

    sops.templates = lib.mkIf config.services.nix-access-tokens.enable {
      "nix-access-tokens" = {
        content = ''
          access-tokens = github.com=${config.sops.secrets."github-token".placeholder}
        '';
        mode = "0440";
      };
    };
  };
}
