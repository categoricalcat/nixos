{
  lib,
  stdenv,
  makeDesktopItem,
  copyDesktopItems,
  curl,
  appimage-run,
}:

stdenv.mkDerivation {
  pname = "fluxer";
  version = "latest";

  src = ./.;

  nativeBuildInputs = [
    copyDesktopItems
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "app.fluxer.FluxerDesktop";
      desktopName = "Fluxer";
      exec = "fluxer %U";
      icon = "fluxer";
      terminal = false;
      type = "Application";
      startupWMClass = "app.fluxer.FluxerDesktop";
      genericName = "Instant Messenger";
      comment = "Instant messaging and VoIP application";
      keywords = [
        "chat"
        "im"
        "messaging"
        "messenger"
        "voip"
        "voice"
        "video"
        "call"
      ];
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
      startupNotify = true;
      mimeTypes = [ "x-scheme-handler/fluxer" ];
      actions = {
        open-settings = {
          name = "Open Settings";
          exec = "fluxer --fluxer-task=open-settings %U";
        };
        new-dm = {
          name = "New Direct Message";
          exec = "fluxer --fluxer-task=new-dm %U";
        };
      };
      extraConfig = {
        SingleMainWindow = "true";
        "X-GNOME-UsesNotifications" = "true";
      };
    })
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/icons/hicolor/1024x1024/apps

    substitute ${./fluxer-launcher.sh} $out/bin/fluxer \
      --subst-var-by system ${stdenv.hostPlatform.system} \
      --subst-var-by curl ${curl}/bin/curl \
      --subst-var-by appimageRun ${appimage-run}/bin/appimage-run
    patchShebangs $out/bin/fluxer
    chmod +x $out/bin/fluxer

    cp ${./fluxer.png} $out/share/icons/hicolor/1024x1024/apps/fluxer.png

    runHook postInstall
  '';

  postFixup = ''
    ln -s $out/share/applications/app.fluxer.FluxerDesktop.desktop \
      $out/share/applications/fluxer.desktop
  '';

  meta = with lib; {
    description = "Instant messaging and VoIP application";
    homepage = "https://fluxer.app";
    license = [
      licenses.agpl3Plus
      licenses.cc-by-sa-40
    ];
    mainProgram = "fluxer";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
