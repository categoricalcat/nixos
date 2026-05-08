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
      xorg.libX11
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libxcb
      xorg.libxshmfence
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
