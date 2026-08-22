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
      let
        baseColors = lib.filterAttrs (n: _: lib.hasPrefix "base" n) rawColors;
        meta = {
          slug = rawColors.slug or rawColors.scheme;
          inherit (rawColors) scheme;
          author = rawColors.author or "";
        };
      in
      rawColors
      // meta
      // {
        withHashtag = (builtins.mapAttrs (_name: value: "#${value}") baseColors) // meta;
      };

  # Always generate the theme
  hasStylix = true;

  extName = "stylix";
  extPublisher = "stylix";
  extVersion = "0.1.0";
  extUniqueId = "${extPublisher}.${extName}";
  extLabel = "yimoka";

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
            "namespace" = base0A;
            "class" = base0A;
            "interface" = base0A;
            "type" = base0A;
            "struct" = base0E;
            "enum" = base0A;
            "typeParameter" = base0A;
            "event" = base0A;
            "enumMember" = base09;
            "constant" = base09;
            "string" = base0B;
            "number" = base09;
            "boolean" = base09;
            "label" = base0A;
            "operator" = base05;
            "keyword" = base0E;
            "macro" = base08;
            "decorator" = base0D;
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
          tokenColors = with colors.withHashtag; [
            {
              name = "Comment";
              scope = [
                "comment"
                "punctuation.definition.comment"
              ];
              settings = {
                foreground = base03;
                fontStyle = "italic";
              };
            }
            {
              name = "Variables";
              scope = [
                "variable"
                "string constant.other.placeholder"
              ];
              settings.foreground = base05;
            }
            {
              name = "Properties, fields (fallback)";
              scope = [
                "variable.other.object.property"
                "variable.other.property"
                "support.variable.property"
              ];
              settings.foreground = base08;
            }
            {
              name = "Keywords, storage, control";
              scope = [
                "keyword"
                "storage.type"
                "storage.modifier"
              ];
              settings.foreground = base0E;
            }
            {
              name = "Functions, methods";
              scope = [
                "entity.name.function"
                "support.function"
                "entity.name.function.method"
              ];
              settings.foreground = base0D;
            }
            {
              name = "Numbers, constants, booleans";
              scope = [
                "constant.numeric"
                "constant.language"
                "constant.character"
              ];
              settings.foreground = base09;
            }
            {
              name = "Strings, symbols";
              scope = [
                "string"
                "constant.other.symbol"
              ];
              settings.foreground = base0B;
            }
            {
              name = "Types, classes, tags";
              scope = [
                "entity.name.type"
                "entity.name.class"
                "entity.name.tag"
                "support.class"
                "support.type"
              ];
              settings.foreground = base0A;
            }
            {
              name = "Operators, punctuation";
              scope = [
                "keyword.operator"
                "punctuation"
              ];
              settings.foreground = base05;
            }
            {
              name = "Embedded, delimiters, deprecated";
              scope = [
                "punctuation.section.embedded"
                "invalid.deprecated"
              ];
              settings.foreground = base0F;
            }
            {
              name = "Regex, escape chars, CSS property names";
              scope = [
                "string.regexp"
                "constant.character.escape"
                "support.type.property-name.css"
              ];
              settings.foreground = base0C;
            }
            {
              name = "Diff inserted";
              scope = [ "markup.inserted" ];
              settings.foreground = base0B;
            }
            {
              name = "Diff deleted";
              scope = [ "markup.deleted" ];
              settings.foreground = base08;
            }
            {
              name = "Diff changed";
              scope = [ "markup.changed" ];
              settings.foreground = base0E;
            }
            {
              name = "Markdown headings";
              scope = [ "markup.heading" ];
              settings.foreground = base0D;
            }
            {
              name = "Markdown bold/italic";
              scope = [
                "markup.bold"
                "markup.italic"
              ];
              settings.foreground = base05;
            }
            {
              name = "JSON keys";
              scope = [ "support.type.property-name.json" ];
              settings.foreground = base0D;
            }
            {
              name = "URL/link";
              scope = [
                "markup.underline.link"
                "string.other.link"
              ];
              settings = {
                foreground = base05;
                fontStyle = "underline";
              };
            }
            {
              name = "Invalid/illegal";
              scope = [ "invalid.illegal" ];
              settings.foreground = base08;
            }
          ];
        }
      );

  # package.json for the extension, with the correct dark uiTheme
  packageJson = builtins.toJSON {
    name = extName;
    displayName = extLabel;
    version = extVersion;
    publisher = extPublisher;
    description = "${extLabel} theme, configured via NixOS or Home Manager.";
    categories = [ "Themes" ];
    engines.vscode = "^1.43.0";
    contributes.themes = [
      {
        label = extLabel;
        uiTheme = "vs-dark";
        path = "./themes/stylix.json";
      }
    ];
  };

  vsixManifest = builtins.toFile "extension.vsixmanifest" ''
    <?xml version="1.0" encoding="utf-8"?>
    <PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011">
      <Metadata>
        <Identity Language="en-US" Id="${extName}" Version="${extVersion}" Publisher="${extPublisher}" />
        <DisplayName>${extLabel}</DisplayName>
        <Description>${extLabel} theme, configured via NixOS or Home Manager.</Description>
        <Categories>Theme</Categories>
        <Tags>theme,${extLabel}</Tags>
      </Metadata>
      <Installation>
        <InstallationTarget Id="Microsoft.VisualStudio.Code" Version="[1.43.0,)" />
      </Installation>
      <Dependencies />
      <Assets>
        <Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" />
      </Assets>
    </PackageManifest>
  '';

  vsixContentTypes = builtins.toFile "Content_Types.xml" ''
    <?xml version="1.0" encoding="utf-8"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="vsixmanifest" ContentType="text/xml" />
      <Default Extension="json" ContentType="application/json" />
    </Types>
  '';

  # Unpacked extension directory (used for opencode, which has no vsix CLI)
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

  # Proper .vsix so editors register it in their extension registry instead of
  # pruning it as an uninstalled leftover.
  stylixVsix =
    pkgs.runCommandLocal "${extLabel}.vsix"
      {
        theme = themeJson;
        manifest = packageJson;
        vsixmanifest = vsixManifest;
        contentTypes = vsixContentTypes;
        passAsFile = [
          "theme"
          "manifest"
        ];
        nativeBuildInputs = [ pkgs.zip ];
      }
      ''
        mkdir -p extension/themes
        cp "$manifestPath" extension/package.json
        cp "$themePath" extension/themes/stylix.json
        cp "$vsixmanifest" extension.vsixmanifest
        cp "$contentTypes" '[Content_Types].xml'
        zip -qr "$out" extension '[Content_Types].xml' extension.vsixmanifest
      '';

in
{
  config = lib.mkIf (config.serverMode.developer && hasStylix) {
    # opencode has no --install-extension CLI; keep a plain folder symlink
    home.file = {
      ".opencode/extensions/${extUniqueId}-${extVersion}".source =
        "${stylixThemeExt}/share/vscode/extensions/${extUniqueId}";
    };

    # Install the theme through each editor's own extension CLI so it lands in
    # the editor's registry (extensions.json) and survives the obsolete pruning
    # that otherwise deletes manually-dropped, unregistered extensions.
    home.activation.installYimokaTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      vsix="${stylixVsix}"
      ext_theme="${stylixThemeExt}/share/vscode/extensions/${extUniqueId}/themes/stylix.json"
      log() { printf '%s\n' "yimoka-theme: $*"; }

      # Fresh install per editor: --force overwrites any existing copy, so no
      # uninstall or stale-state cleanup is needed. Skip when already current.
      install_vsix() {
        local bin="$1" label="$2" d="$3"
        local target="$d/${extUniqueId}-${extVersion}/themes/stylix.json"
        if [ -f "$target" ] && cmp -s "$target" "$ext_theme"; then
          log "up to date for $label"
          return 0
        fi
        if out="$("$bin" --install-extension "$vsix" --force 2>&1)"; then
          log "installed for $label"
        elif [ -f "$target" ] && cmp -s "$target" "$ext_theme"; then
          # Antigravity servers unpack and register the extension before
          # failing on a post-install analytics error, so verify by the
          # installed theme file rather than the CLI exit code.
          log "installed for $label (CLI errored after unpack)"
        else
          log "FAILED for $label: $(printf '%s' "$out" | head -n1)"
        fi
      }

      ext_dir_for() {
        case "$1" in
          cursor | nxd-cursor) echo "$HOME/.cursor/extensions" ;;
          code) echo "$HOME/.vscode/extensions" ;;
          codium) echo "$HOME/.vscode-oss/extensions" ;;
          windsurf) echo "$HOME/.windsurf/extensions" ;;
          antigravity) echo "$HOME/.antigravity/extensions" ;;
          antigravity-ide | antigravity-ide-fhs | nxd-antigravity) echo "$HOME/.antigravity-ide/extensions" ;;
          antigravity-server) echo "$HOME/.antigravity-server/extensions" ;;
          antigravity-ide-server) echo "$HOME/.antigravity-ide-server/extensions" ;;
          code-server) echo "$HOME/.local/share/code-server/extensions" ;;
          openvscode-server) echo "$HOME/.openvscode-server/extensions" ;;
          *) echo "" ;;
        esac
      }

      # cursor-server (remote sessions)
      for cs in "$HOME"/.cursor-server/bin/linux-x64/*/bin/cursor-server; do
        if [ -x "$cs" ]; then
          run install_vsix "$cs" "cursor-server" "$HOME/.cursor-server/extensions"
          break
        fi
      done

      # antigravity-ide-server (remote sessions)
      for cs in "$HOME"/.antigravity-ide-server/bin/*/bin/antigravity-ide-server; do
        if [ -x "$cs" ]; then
          run install_vsix "$cs" "antigravity-ide-server" "$HOME/.antigravity-ide-server/extensions"
          break
        fi
      done

      # antigravity-server (remote sessions)
      for cs in "$HOME"/.antigravity-server/bin/*/bin/antigravity-server; do
        if [ -x "$cs" ]; then
          run install_vsix "$cs" "antigravity-server" "$HOME/.antigravity-server/extensions"
          break
        fi
      done

      # generic vscode-based editors, best effort
      for bin in cursor nxd-cursor code codium windsurf antigravity antigravity-ide antigravity-ide-fhs nxd-antigravity antigravity-server code-server openvscode-server; do
        if command -v "$bin" >/dev/null 2>&1; then
          run install_vsix "$bin" "$bin" "$(ext_dir_for "$bin")"
        fi
      done
    '';
  };
}
