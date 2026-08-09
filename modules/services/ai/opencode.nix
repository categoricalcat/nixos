# NixOS companion module for the opencode home-manager config.
# Declares the sops secret opencode reads for its DeepSeek provider
# (`users/programs/opencode.nix`), only on hosts where opencode is enabled.

{ config, lib, ... }:

{
  sops.secrets."tokens/deepseek" =
    lib.mkIf (config.home-manager.users.yi.programs.opencode.enable or false)
      {
        owner = config.users.users.yi.name;
        inherit (config.users.users.yi) group;
        mode = "0400";
      };
}
