{
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
let
  unstable = import ../../modules/nixpkgs-unstable.nix { inherit inputs pkgs; };

  flakeLock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  rootInputs = flakeLock.nodes.root.inputs;

  paths = lib.mapAttrs (
    name: nodeName:
    let
      node = flakeLock.nodes.${nodeName}.original or { };
    in
    if node ? owner && node ? repo then
      "inputs/${node.owner}/${node.repo}" + lib.optionalString (node ? ref) "/${node.ref}"
    else
      "inputs/${name}"
  ) rootInputs;

  homeInputFiles = lib.mapAttrs' (name: _: {
    name = paths.${name};
    value.source = inputs.${name};
  }) rootInputs;
in
{
  imports = [
    inputs.thefiles.homeModules.default
    ../programs/git.nix
    ../programs/tui.nix
    ../programs/ssh
    ../programs/neovim.nix
  ];

  home = {
    packages = with pkgs; [
      unstable.zed-editor
      pnpm
      eslint
      typescript
      npm-check-updates
    ];

    file = homeInputFiles;

    sessionVariables = {
      TERMINFO = "/run/current-system/sw/share/terminfo";
      TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/run/current-system/sw/share/terminfo";
    };
  };

  programs = {
    home-manager.enable = true;

    zsh = {
      enable = true;
      package = unstable.zsh;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      initContent = builtins.readFile "${inputs.thefiles}/.zshrc";
    };
  };
}
