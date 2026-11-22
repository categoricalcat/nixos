# System packages configuration module (Universal Base)

{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    bat
    curl
    dig
    fd
    git
    jq
    killall
    ncdu
    p7zip
    pik
    ripgrep
    sops
    ssh-to-age
    stow
    tree
    unzip
    wget
    zip
    zsh
  ];

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 2d --keep 2";
    flake = "/home/yi/the.files/nixos";
  };
}
