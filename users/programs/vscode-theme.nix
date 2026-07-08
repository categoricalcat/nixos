{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  rawColors = import ../../modules/theme.nix;

  # Evaluate stylix colors if available, otherwise use yimoka theme
  colors =
    if config.lib ? stylix && config.lib.stylix ? colors then
      config.lib.stylix.colors
    else
      rawColors
      // {
        slug = rawColors.scheme;
        withHashtag = builtins.mapAttrs (_name: value: "#${value}") rawColors;
      };

  # Always generate the theme
  hasStylix = true;

  extName = "stylix";
  extPublisher = "stylix";
  extVersion = "0.0.0";
  extUniqueId = "${extPublisher}.${extName}";

  # Use the Stylix VSCode theme template
  themeTemplate = import "${inputs.stylix}/modules/vscode/templates/theme.nix";
  tpl = if hasStylix then themeTemplate colors else { };

  # Match nvim (stylix mini.base16): keep Stylix UI colors, but replace syntax
  # scopes with mini.base16-style mappings.
  themeJson =
    if !hasStylix then
      ""
    else
      builtins.toJSON (
        tpl
        // {
          semanticHighlighting = true;
          semanticTokenColors = with colors.withHashtag; {
            "variable" = base05;
            "parameter" = base05;
            "property" = base08;
            "member" = base08;
            "function" = base0D;
            "method" = base0D;
            "namespace" = base0E;
            "class" = base0A;
            "interface" = base0A;
            "type" = base0A;
            "struct" = base0A;
            "enum" = base0A;
            "typeParameter" = base0A;
            "event" = base0A;
            "enumMember" = base09;
            "constant" = base09;
            "string" = base0B;
            "number" = base09;
            "operator" = base05;
            "keyword" = base0E;
            "macro" = base09;
            "decorator" = base08;
            "regexp" = base0F;
            "modifier" = base0E;
            "comment" = base03;
            "variable.defaultLibrary" = base0C;
            "parameter.defaultLibrary" = base0C;
            "property.defaultLibrary" = base0C;
            "function.defaultLibrary" = base0C;
            "method.defaultLibrary" = base0C;
            "type.defaultLibrary" = base0C;
            "class.defaultLibrary" = base0C;
            "interface.defaultLibrary" = base0C;
            "namespace.defaultLibrary" = base0C;
            "*.defaultLibrary" = base0C;
            "*.deprecated" = base08;
          };
          tokenColors =
            tpl.tokenColors
            ++ (with colors.withHashtag; [
              {
                name = "Nvim mini.base16 Variables";
                scope = [
                  "variable"
                  "variable.parameter"
                  "variable.other"
                  "entity.name.variable"
                  "entity.name.variable.parameter"
                  "entity.name.variable.local"
                ];
                settings.foreground = base05;
              }
              {
                name = "Nvim mini.base16 Properties";
                scope = [
                  "variable.other.object.property"
                  "variable.other.property"
                  "support.variable.property"
                ];
                settings.foreground = base08;
              }
              {
                name = "Nvim mini.base16 Operators";
                scope = [ "keyword.operator" ];
                settings.foreground = base05;
              }
            ]);
        }
      );

  # Generate our own package.json with the correct dark uiTheme
  packageJson = builtins.toJSON {
    name = extName;
    displayName = "Stylix";
    version = extVersion;
    publisher = extPublisher;
    description = "Theme configured via NixOS or Home Manager.";
    categories = [ "Themes" ];
    engines.vscode = "^1.43.0";
    contributes.themes = [
      {
        label = "Stylix";
        uiTheme = "vs-dark";
        path = "./themes/stylix.json";
      }
    ];
  };

  # Build the extension directory
  stylixThemeExt =
    pkgs.runCommandLocal "${extName}-vscode"
      {
        vscodeExtUniqueId = extUniqueId;
        vscodeExtPublisher = extPublisher;
        version = extVersion;
        theme = themeJson;
        manifest = packageJson;
        passAsFile = [
          "theme"
          "manifest"
        ];
      }
      ''
        mkdir -p "$out/share/vscode/extensions/$vscodeExtUniqueId/themes"
        cp "$manifestPath" "$out/share/vscode/extensions/$vscodeExtUniqueId/package.json"
        cp "$themePath" "$out/share/vscode/extensions/$vscodeExtUniqueId/themes/stylix.json"
      '';

  # Paths to extension directories of various vscode-based IDEs
  ideDirs = [
    ".vscode"
    ".cursor"
    ".cursor-server"
    ".antigravity"
    ".antigravity-ide"
    ".antigravity-server"
    ".vscode-oss"
    ".windsurf"
    ".openvscode-server"
    ".opencode"
  ];

  fileMappings =
    lib.genAttrs (map (dir: "${dir}/extensions/${extUniqueId}-${extVersion}") ideDirs)
      (_path: {
        source = "${stylixThemeExt}/share/vscode/extensions/${extUniqueId}";
      });
in
{
  config = lib.mkIf hasStylix {
    home.file = fileMappings;
  };
}
