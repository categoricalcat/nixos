# System packages configuration module (Universal Base)

{
  pkgs,
  ...
}:
let
  wrappers = import ../../packages/wrappers.nix { inherit pkgs; };
in
{
  environment.systemPackages =
    (with pkgs; [
      bat
      curl
      dig
      fd
      git
      jq
      killall
      ncdu
      p7zip
      ripgrep
      sops
      stow
      tree
      unzip
      wget
      zip
      zsh
    ])
    ++ (builtins.attrValues wrappers);

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 2d --keep 2";
    flake = "/home/yi/the.files/nixos";
  };
}
