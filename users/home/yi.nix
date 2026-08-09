{
  pkgs,
  lib,
  desktopEnvironment ? null,
  desktopShell ? null,
  headless ? false,
  developer ? (!headless),
  ...
}:
let
  homeDirectory = "/home/yi";
in
{
  imports = [
    ./common.nix
  ]
  ++ lib.optionals developer [
    ../programs/opencode.nix
  ]
  ++ lib.optionals (desktopEnvironment != null) [
    ../programs/fcitx5.nix
    ../programs/kitty.nix
    ../programs/mprisence.nix
  ]
  ++ lib.optionals (desktopEnvironment == "niri" && desktopShell == "dms") [
    ../programs/dms.nix
  ]
  ++ lib.optionals (desktopEnvironment == "niri" && desktopShell == "noctalia") [
    ../programs/noctalia
  ]
  ++ lib.optionals (desktopEnvironment == "niri") [
    ../programs/niri.nix
  ];

  home = {
    username = "yi";
    inherit homeDirectory;

    packages =
      lib.optionals developer (
        with pkgs;
        [
          bun
          nodejs

          sshfs
        ]
      )
      ++ lib.optionals developer (
        with pkgs.haskellPackages;
        [
          ghc
          cabal-install
          haskell-language-server
          stack
          ghcid
        ]
      )
      ++ lib.optionals (desktopEnvironment != null) (
        with pkgs;
        [
          smile
          wtype
          ksnip
          wl-clipboard
        ]
      );
  };
}
