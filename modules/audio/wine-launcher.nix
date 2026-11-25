# Shared plumbing for the Wine plugin prefixes. amplitube.nix uses the launcher
# skeleton; yabridge.nix consumes the prefix registry and the bridge packages.
{ pkgs }:
let
  # Single source of truth for the Wine every audio prefix runs on: the newest
  # build in nixpkgs (staging). nixpkgs builds yabridge against
  # wineWow64Packages.yabridge (Wine 9.21); the host stub hard-codes that
  # WINELOADER, so rebuild the nixpkgs packages against staging.
  wine = pkgs.wineWow64Packages.staging;
  wineWow64Packages = pkgs.wineWow64Packages.extend (
    _self: _super: {
      yabridge = wine;
    }
  );

  yabridge = pkgs.yabridge.override { inherit wineWow64Packages; };
  yabridgectl = pkgs.yabridgectl.override {
    inherit yabridge wineWow64Packages;
  };

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
        pkgs.diffutils
        pkgs.gnugrep
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
        [[ -t 2 ]] || exec > >(systemd-cat -t ${pkgs.lib.escapeShellArg name}) 2>&1
        export WINEPREFIX="$HOME/${prefix}"

        need() {
          [[ -f "$1" ]] && return
          printf '%s\n' "$2" >&2
          notify-send ${pkgs.lib.escapeShellArg title} "$2" || true
          exit 1
        }

        # Wine copies builtins into the prefix once. The store mtime is 1, so
        # .update-timestamp already matches a new Wine and wineboot will not
        # recopy them; `wineboot --update` also loops explorer.exe on a prefix
        # that has apps. Copy the builtins ourselves as writable 0644 (cp -a
        # would leave 0444 store files that fail to overwrite on the next Wine
        # update), skipping .a import libraries and preserving native DLLs. The
        # "synced-rw" stamp supersedes earlier stamps so existing prefixes
        # repair read-only builtins on the next launch.
        marker="$WINEPREFIX/.nix-wine-build"
        stamp="${wine} synced-rw"

        copy_builtins() {
          local src="$1" dest="$2" target name
          [[ -d "$src" && -d "$dest" ]] || return 0
          for target in "$src"/*; do
            [[ -f "$target" ]] || continue
            name="''${target##*/}"
            [[ "$name" == *.a ]] && continue
            if [[ -e "$dest/$name" && ! -f "$dest/$name" ]]; then
              continue
            fi
            if [[ -f "$dest/$name" ]]; then
              if [[ ! -L "$dest/$name" && -w "$dest/$name" ]] && cmp -s "$target" "$dest/$name"; then
                continue
              fi
              grep -aqE 'Wine (builtin|placeholder) DLL' "$dest/$name" || continue
            fi
            install -m0644 "$target" "$dest/$name"
          done
        }

        init_prefix() {
          if [[ -f "$marker" && "$(cat "$marker")" == "$stamp" ]]; then
            return
          fi
          if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
            mkdir -p "$WINEPREFIX"
            # Wine Mono and Gecko are not bundled; skip their download prompts
            WINEDLLOVERRIDES="$WINEDLLOVERRIDES;mscoree,mshtml=" wineboot --init
          else
            wineserver -k || true
            wineserver -w || true
            copy_builtins "${wine}/lib/wine/x86_64-windows" "$WINEPREFIX/drive_c/windows/system32"
            copy_builtins "${wine}/lib/wine/i386-windows" "$WINEPREFIX/drive_c/windows/syswow64"
          fi
        ${pkgs.lib.optionalString (init != "") "${init}\n"}  wineserver -w
          printf '%s\n' "$stamp" > "$marker"
        }

        ${body}'';
    };
in
{
  inherit
    mkLauncher
    mkPrefix
    wine
    yabridge
    yabridgectl
    ;
}
