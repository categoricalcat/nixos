{
  pkgs,
  lib,
  desktopEnvironment ? null,
  ...
}:
let
  homeDirectory = "/home/yi";
in
{
  imports = [
    ./common.nix
    ../programs/fastfetch.nix
    ../programs/opencode.nix
  ]
  ++ lib.optionals (desktopEnvironment != null) [
    ../programs/alacritty.nix
    ../programs/mprisence.nix
    ../programs/fcitx5.nix
    ../../modules/desktop/web-apps.nix
  ]
  ++ lib.optionals (desktopEnvironment == "niri") [
    ../programs/dms.nix
  ];

  home.username = "yi";
  home.homeDirectory = homeDirectory;

  home.packages =
    with pkgs;
    with haskellPackages;
    [
      bun
      nodejs

      sshfs
      ghc
      cabal-install
      haskell-language-server
      stack
      ghcid
    ];
}
