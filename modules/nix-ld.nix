{
  pkgs,
  config,
  lib,
  ...
}:

{
  programs.nix-ld = {
    enable = lib.mkDefault true;
    libraries = lib.mkIf config.programs.nix-ld.enable (
      with pkgs;
      [
        stdenv.cc.cc
        zlib
        glib
        nss
        nspr
        expat
        dbus.lib
        udev
      ]
      ++ lib.optionals (!config.serverMode.headless) [
        alsa-lib
        atk
        at-spi2-atk
        at-spi2-core
        libdrm
        mesa
        libx11
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
        libxcb
        libxshmfence
        libGL
        libgbm
        pango
        cairo
        cups
        libxkbcommon
        fontconfig
        libxcb-util
        libxcb-cursor
      ]
    );
  };
}
