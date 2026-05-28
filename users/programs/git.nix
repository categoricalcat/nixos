{ config, inputs, ... }:
let
  keys = import ../../secrets/keys.nix;
in
{
  # Include the base dotfiles .gitconfig and override the signing key
  # for NixOS (uses a dedicated git signing key).
  home.file.".gitconfig" = {
    text = ''
      [include]
      	path = ${inputs.thefiles}/.gitconfig

      [user]
      	signingkey = ${keys.paths.gitSigningKey config.home.homeDirectory}
    '';
    force = true;
  };
}
