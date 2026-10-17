{
  lib,
  config,
  ...
}:
{
  imports = [
    ./shell.nix
  ];

  host = {
    desktopEnvironment = lib.mkDefault null;
    desktopShell = lib.mkDefault null;
    developer = lib.mkDefault true;
    tui = lib.mkDefault true;
    vr = lib.mkDefault false;
  };

  serverMode = {
    headless = lib.mkDefault (config.host.desktopEnvironment == null);
    developer = lib.mkDefault config.host.developer;
    tui = lib.mkDefault config.host.tui;
  };

  desktop = {
    keyboard = lib.mkDefault "us";
    monitors = lib.mkDefault [ ];
  };

  home = {
    username = lib.mkDefault "root";
    homeDirectory = lib.mkDefault "/root";

    # Allow root (libgit2 / git) to inspect and build flakes inside yi-owned worktrees.
    file.".gitconfig" = {
      text = ''
        [include]
        	path = ${../assets/dotfiles/gitconfig}

        [commit]
        	gpgsign = false

        [safe]
        	directory = *
      '';
      force = true;
    };
  };
}
