{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.host.desktopEnvironment != null) {
    xdg.configFile."fluxer-flags.conf".text = ''
      --enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,VaapiIgnoreDriverChecks,AcceleratedVideoEncoder
      --use-gl=angle
      --use-angle=gl
      --disable-gpu-sandbox
    '';
  };
}
