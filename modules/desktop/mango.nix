{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

let
  patchedMango = inputs.mango.packages.${pkgs.stdenv.hostPlatform.system}.mango.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../packages/mango-monitor-focus.patch
    ];

    postInstall = (old.postInstall or "") + ''
      substituteInPlace $out/share/wayland-sessions/mango.desktop \
        --replace-fail "DesktopNames=mango;wlroots" \
        "DesktopNames=mango;wlroots;X-NIXOS-SYSTEMD-AWARE"
    '';
  });
in
{
  config = lib.mkIf (config.desktop.environment == "mango") {
    programs.mango.package = patchedMango;

    home-manager.users.yi.imports = [
      inputs.mango.hmModules.mango
      inputs.dms.homeModules.dank-material-shell
      ../../users/programs/dms.nix
      ../../users/programs/noctalia
      ../../users/programs/mango.nix
      {
        wayland.windowManager.mango.package = patchedMango;
      }
    ];

    environment.systemPackages = with pkgs; [
      wlr-randr
    ];

    programs.mango.enable = true;
  };
}
