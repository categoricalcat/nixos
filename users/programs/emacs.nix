{
  inputs,
  config,
  lib,
  options,
  ...
}:
{
  imports = [ inputs.nix-doom-emacs-unstraightened.homeModule ];

  config = lib.mkMerge [
    {
      programs.doom-emacs = {
        enable = true;
        doomDir = ../assets/dotfiles/doom; # Directory containing init.el, config.el, packages.el
      };
    }
    (lib.optionalAttrs (options ? stylix) {
      stylix.targets.emacs.enable = true;
      programs.doom-emacs.extraPackages = config.programs.emacs.extraPackages;
    })
  ];
}
