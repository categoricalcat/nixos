{ pkgs, ... }:

with pkgs;
[
  gnomeExtensions.vitals
  # gnomeExtensions.gtile
  gnomeExtensions.kimpanel
  # gnomeExtensions.paperwm
  gnomeExtensions.pip-on-top
  gnomeExtensions.impatience
  gnomeExtensions.user-themes
  (gnomeExtensions.mpris-label.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace players.js \
        --replace-fail "import Gio from 'gi://Gio';" "import Gio from 'gi://Gio'; import GioUnix from 'gi://GioUnix';" \
        --replace-fail "Gio.DesktopAppInfo" "GioUnix.DesktopAppInfo"
    '';
  }))
  (gnomeExtensions.appindicator.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace trayIconsManager.js \
        --replace-fail "Util.Logger.warning" "Util.Logger.warn"
    '';
  }))
  gnomeExtensions.dash-to-panel
  gnomeExtensions.weather-oclock
  # this bitch crashing: gnomeExtensions.tiling-assistant
  gnomeExtensions.clipboard-indicator
  gnomeExtensions.vertical-workspaces
  gnomeExtensions.switch-workspaces-on-active-monitor
]
