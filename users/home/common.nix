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

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = builtins.readFile "${inputs.thefiles}/.zshrc";
  };

  imports = [
    inputs.thefiles.homeModules.default
    ../programs/git.nix
    ../programs/tui.nix
    ../programs/ssh
  ];

  home.file = {
    "NixOS/nixpkgs".source = inputs.nixpkgs;
    "nix-community/home-manager".source = inputs.home-manager;
    "AvengeMedia/DankMaterialShell".source = inputs.dms;
  };
}
