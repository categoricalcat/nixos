{
  pkgs,
  inputs,
  ...
}:
{
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    pnpm
    eslint
    typescript
    npm-check-updates
  ];

  imports = [
    inputs.thefiles.homeModules.default
    ../programs/git.nix
    ../programs/tui.nix
    ../programs/ssh
  ];

  home.file = {
    "NixOS/nixpkgs".source = inputs.nixpkgs;
    "nix-community/home-manager".source = inputs.home-manager;
  };
}
