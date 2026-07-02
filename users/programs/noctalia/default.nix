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

    customPalettes.yimoka =
      let
        tc = import ../../../modules/theme.nix;
        c = name: "#${tc.${name}}";
      in
      {
        dark = {
          primary = c "base0D";
          onPrimary = c "base00";
          secondary = c "base0E";
          onSecondary = c "base00";
          tertiary = c "base0C";
          onTertiary = c "base00";
          error = c "base08";
          onError = c "base00";
          surface = c "base00";
          onSurface = c "base05";
          surfaceVariant = c "base01";
          onSurfaceVariant = c "base05";
          outline = c "base03";
          shadow = c "base00";
          hover = c "base02";
          onHover = c "base05";
          terminal = {
            normal = {
              black = c "base00";
              red = c "base08";
              green = c "base0B";
              yellow = c "base0A";
              blue = c "base0D";
              magenta = c "base0E";
              cyan = c "base0C";
              white = c "base05";
            };
            bright = {
              black = c "base03";
              red = c "base08";
              green = c "base0B";
              yellow = c "base0A";
              blue = c "base0D";
              magenta = c "base0E";
              cyan = c "base0C";
              white = c "base07";
            };
            foreground = c "base05";
            background = c "base00";
            cursor = c "base05";
            cursorText = c "base00";
            selectionFg = c "base05";
            selectionBg = c "base02";
          };
        };
      };
  };

  # Make Noctalia settings mutable at runtime (same pattern as DMS)
  # home.activation.makeNoctaliaMutable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
  #   for file in config.toml; do
  #     target="$HOME/.config/noctalia/$file"
  #     if [ -L "$target" ]; then
  #       store_path=$(readlink -f "$target")
  #       rm -f "$target"
  #       cp "$store_path" "$target"
  #       chmod u+w "$target"
  #     fi
  #   done
  # ';

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
