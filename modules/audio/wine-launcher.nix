# Shared plumbing for the Wine plugin prefixes. Both plugin modules
# (amplitube, toontrack) need the same prefix layout and the same launcher
# skeleton; yabridge.nix consumes the prefix registry those modules populate.
{ pkgs }:
let
  # yabridge's stub hard-codes this exact Wine build as WINELOADER; running the
  # prefixes and installers under the same build avoids wineserver version mismatches.
  wine = pkgs.wineWow64Packages.yabridge;

  # The prefix path is authored here only; modules pass it to the registry as an
  # absolute path and to their launcher as a path relative to $HOME.
  mkPrefix =
    home: name:
    let
      relative = ".local/share/wineprefixes/${name}";
    in
    {
      prefix = relative;
      vst3Dir = "${home}/${relative}/drive_c/Program Files/Common Files/VST3";
    };

  # `''` strips the common indentation of the literal text, but never reindents an
  # interpolated string, so the template is written flush-left: `init` and `body`
  # land exactly where callers write them, with no hidden column offset.
  mkLauncher =
    {
      name,
      title,
      prefix,
      body,
      init ? "",
      runtimeInputs ? [ ],
      runtimeEnv ? { },
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.libnotify
        pkgs.systemd
        wine
      ]
      ++ runtimeInputs;
      runtimeEnv = {
        WINEARCH = "win64";
        WINEDLLOVERRIDES = "winemenubuilder.exe=d";
      }
      // runtimeEnv;
      text = ''
        # Desktop-launched stdout/stderr are discarded; log via the journal when not on a tty
        [[ -t 2 ]] || exec > >(systemd-cat -t ${name}) 2>&1
        export WINEPREFIX="$HOME/${prefix}"

        need() {
          [[ -f "$1" ]] && return
          printf '%s\n' "$2" >&2
          notify-send "${title}" "$2" || true
          exit 1
        }

        init_prefix() {
          [[ -f "$WINEPREFIX/system.reg" ]] && return
          mkdir -p "$WINEPREFIX"
          # Wine Mono and Gecko are not bundled; skip their download prompts
          WINEDLLOVERRIDES="$WINEDLLOVERRIDES;mscoree,mshtml=" wineboot --init
        ${init}  wineserver -w
        }

        ${body}'';
    };
in
{
  inherit mkLauncher mkPrefix wine;
}
