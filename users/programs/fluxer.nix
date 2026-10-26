{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Flatpak cannot follow a /nix/store symlink, so activation installs a regular file.
  flagsFile = pkgs.writeText "fluxer-flags.conf" ''
    --enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,VaapiIgnoreDriverChecks,AcceleratedVideoEncoder
    --use-gl=angle
    --use-angle=gl
    --disable-gpu-sandbox
  '';
in
{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.host.desktopEnvironment != null) {
    home.activation.realizeFluxerFlags = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      target="$HOME/.var/app/app.fluxer.Fluxer/config/fluxer-flags.conf"
      run install -d -m 0755 "$(dirname "$target")"
      run install -m 0644 ${flagsFile} "$target"
    '';
  };
}
