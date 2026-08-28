{
  pkgs,
  lib,
  config,
  ...
}:

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

  host = {
    desktopEnvironment = lib.mkDefault null;
    desktopShell = lib.mkDefault null;
    developer = lib.mkDefault true;
    tui = lib.mkDefault true;
    vr = lib.mkDefault false;
  };

  serverMode = {
    headless = lib.mkDefault (config.host.desktopEnvironment == null);
    developer = lib.mkDefault config.host.developer;
    tui = lib.mkDefault config.host.tui;
  };

  desktop = {
    keyboard = lib.mkDefault "us";
    monitors = lib.mkDefault [ ];
  };

  home = {
    username = lib.mkDefault "yi";
    homeDirectory = lib.mkDefault (
      if pkgs.stdenv.hostPlatform.isDarwin then "/Users/yi" else "/home/yi"
    );

    packages =
      lib.optionals config.serverMode.developer (
        with pkgs;
        [
          bun
          nodejs

          sshfs
        ]
      )
      ++ lib.optionals config.serverMode.developer (
        with pkgs.haskellPackages;
        [
          ghc
          cabal-install
          haskell-language-server
          stack
          ghcid
        ]
      )
      ++ lib.optionals (pkgs.stdenv.hostPlatform.isLinux && config.host.desktopEnvironment != null) (
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
