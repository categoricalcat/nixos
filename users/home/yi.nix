{
  pkgs,
  lib,
  desktopEnvironment ? null,
  desktopShell ? null,
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
    ../../modules/desktop/web-apps.nix
  ]
  ++ lib.optionals (desktopEnvironment == "niri" && desktopShell == "dms") [
    ../programs/dms.nix
  ]
  ++ lib.optionals (desktopEnvironment == "niri" && desktopShell == "noctalia") [
    ../programs/noctalia.nix
  ]
  ++ lib.optionals (desktopEnvironment == "niri") [
    ../programs/niri.nix
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
    ]
    ++ lib.optionals (desktopEnvironment != null) [
      smile
      wtype
      ksnip
      wl-clipboard
    ];
}
