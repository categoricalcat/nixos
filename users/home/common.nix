{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (config.serverMode) developer;
  inherit (config.host) vr;
in
{
  imports = [
    ./shell.nix
    ./ai-policies.nix
    ../programs/git.nix
    ../programs/ssh
    ../programs/vscode-theme.nix
    ../programs/khal.nix
  ];

  home = {
    packages = lib.optionals developer (
      with pkgs;
      [
        npm-check-updates
        rtk
      ]
    );

    file = lib.mkIf vr {
      ".config/openxr/1/active_runtime.json".text = ''
        {
          "file_format_version": "1.0.0",
          "runtime": {
            "VALVE_runtime_is_steamvr": true,
            "library_path": "${config.home.homeDirectory}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrclient.so",
            "name": "SteamVR"
          }
        }
      '';
    };

    activation.realizeSshConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run install -d -m 0700 "$HOME/.ssh"
      if [ -L "$HOME/.ssh/config" ]; then
        src="$(readlink -f "$HOME/.ssh/config")"
        run rm -f "$HOME/.ssh/config"
        run install -m 0600 "$src" "$HOME/.ssh/config"
      fi
    '';
  };
}
