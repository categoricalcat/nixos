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
    ../../modules/keyboard/fcitx5.nix
    ./common.nix
    ../programs/opencode.nix
    ../programs/kitty.nix
    ../programs/mprisence.nix
    ../programs/fluxer.nix
  ];

  host = {
    desktopEnvironment = lib.mkDefault null;
    desktopShell = lib.mkDefault null;
    vr = lib.mkDefault false;
  };

  serverMode = {
    headless = lib.mkDefault (config.host.desktopEnvironment == null);
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
      (with pkgs; [
        bun
        nodejs

        sshfs
      ])
      ++ (with pkgs.haskellPackages; [
        ghc
        cabal-install
        haskell-language-server
        stack
        ghcid
      ])
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
