# Wraps pkgs.zellij with runtime GUI/fontconfig RPATHs, icons, and desktop entry
# without recompiling zellij-unwrapped or leaking LD_LIBRARY_PATH to child shells.
{
  lib,
  symlinkJoin,
  patchelf,
  makeDesktopItem,
  zellij,
  fontconfig,
  wayland,
  libxkbcommon,
  libglvnd,
  libx11,
  libxcb,
  libxcursor,
  libxrender,
  libxi,
}:

let
  runtimeLibs = [
    fontconfig.lib
    wayland
    libxkbcommon
    libglvnd
    libx11
    libxcb
    libxcursor
    libxrender
    libxi
  ];

  desktopItem = makeDesktopItem {
    name = "dev.zellij.Zellij";
    desktopName = "Zellij";
    genericName = "Terminal Workspace";
    comment = "Manage Your Terminal Applications";
    exec = "zellij terminal";
    tryExec = "zellij";
    icon = "dev.zellij.Zellij";
    terminal = false;
    startupNotify = true;
    startupWMClass = "dev.zellij.Zellij";
    categories = [
      "System"
      "TerminalEmulator"
    ];
    keywords = [
      "terminal"
      "multiplexer"
      "shell"
      "workspace"
    ];
    actions = {
      inbox = {
        name = "Show Inbox";
        exec = "zellij terminal --inbox";
      };
      sessions = {
        name = "Show Sessions";
        exec = "zellij terminal --sessions";
      };
      new-window = {
        name = "New Window";
        exec = "zellij terminal";
      };
    };
    extraConfig = {
      X-TerminalArgExec = "-e";
      X-TerminalArgDir = "--working-directory=";
      X-TerminalArgHold = "--hold";
      X-ExecArg = "-e";
      X-Zellij-Installed = "true";
    };
  };
in
symlinkJoin {
  pname = "${zellij.pname}-desktop";
  inherit (zellij) version meta;

  __structuredAttrs = true;
  strictDeps = true;

  paths = [ zellij ];
  nativeBuildInputs = [ patchelf ];

  postBuild = ''
    rm "$out/bin/zellij" "$out/bin/zellij-terminal"
    cp -L "${zellij}/bin/zellij" "$out/bin/zellij"
    cp -L "${zellij}/bin/zellij-terminal" "$out/bin/zellij-terminal"
    chmod u+w "$out/bin/zellij" "$out/bin/zellij-terminal"
    patchelf --add-rpath "${lib.makeLibraryPath runtimeLibs}" "$out/bin/zellij"
    chmod 0555 "$out/bin/zellij" "$out/bin/zellij-terminal"

    env -i \
      HOME="$TMPDIR/zellij-home" \
      WAYLAND_DISPLAY="wayland-1" \
      XDG_DATA_HOME="$TMPDIR/zellij-share" \
      "$out/bin/zellij" setup --install-desktop-entry >/dev/null
    mkdir -p "$out/share/icons"
    cp -r "$TMPDIR/zellij-share/icons/hicolor" "$out/share/icons/"

    install -Dm644 "${desktopItem}/share/applications/dev.zellij.Zellij.desktop" \
      "$out/share/applications/dev.zellij.Zellij.desktop"
    substituteInPlace "$out/share/applications/dev.zellij.Zellij.desktop" \
      --replace-fail "TryExec=zellij" "TryExec=$out/bin/zellij" \
      --replace-fail "Exec=zellij terminal" "Exec=$out/bin/zellij terminal"
  '';
}
