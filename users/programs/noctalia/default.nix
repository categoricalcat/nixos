{
  inputs,
  pkgs,
  lib,
  ...
}:

let
  noctaliaPackage = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  noctaliaConfig = fromTOML (builtins.readFile ./config.toml);
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    package = noctaliaPackage;

    settings = noctaliaConfig;
  };

  # Make Noctalia settings mutable at runtime (same pattern as DMS)
  home.activation.makeNoctaliaMutable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for file in config.toml; do
      target="$HOME/.config/noctalia/$file"
      if [ -L "$target" ]; then
        store_path=$(readlink -f "$target")
        rm -f "$target"
        cp "$store_path" "$target"
        chmod u+w "$target"
      fi
    done
  '';

  xdg.configFile."autostart/noctalia-shell.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Noctalia Shell
    Comment=Wayland desktop shell
    Exec=env QT_IM_MODULE= ${lib.getExe noctaliaPackage}
    Terminal=false
    X-GNOME-Autostart-enabled=true
  '';
}
