{ config, lib, ... }:

{
  options.services.nix-access-tokens.enable = lib.mkEnableOption "GitHub access token for Nix flake fetches (sops secret nix/access-tokens)";

  # Opt-in: enabling without the nix.access-tokens key in the host's sops file fails sops-install-secrets.
  # Fine-grained PAT, public repos read-only, no permissions — see docs/src/services/secrets.md.
  config = lib.mkIf config.services.nix-access-tokens.enable {
    sops.secrets."nix/access-tokens" = {
      mode = "0440";
      group = "wheel";
    };

    nix.extraOptions = ''
      !include ${config.sops.secrets."nix/access-tokens".path}
    '';
  };
}
