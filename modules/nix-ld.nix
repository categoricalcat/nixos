{ pkgs, ... }:

{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      alsa-lib
      glib
      nss
      nspr
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
      expat
      pango
      cairo
      cups
      dbus.lib
      udev
      libxkbcommon
    ];
  };
}
