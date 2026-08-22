{
  pkgs,
  lib,
  config,
  ...
}:
let
  homeDirectory = "/home/yi";
  inherit (config.host) desktopEnvironment;
  inherit (config.serverMode) developer;
in
{
  imports = [
    ../../modules/options/host.nix
    ../../modules/options/server-mode.nix
    ../../modules/options/desktop.nix
    ./common.nix
    ../programs/opencode.nix
    ../programs/fcitx5.nix
    ../programs/kitty.nix
    ../programs/mprisence.nix
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
