{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  noctaliaPackage = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia-shell = {
    enable = true;
    package = noctaliaPackage;
    settings = { };
  };

  xdg.configFile."autostart/noctalia-shell.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Noctalia Shell
    Comment=Wayland desktop shell
    Exec=${lib.getExe noctaliaPackage}
    Terminal=false
    X-GNOME-Autostart-enabled=true
  '';
}
