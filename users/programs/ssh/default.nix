{
  lib,
  pkgs,
  ...
}:
let
  keys = import ../../../secrets/keys.nix;
  allAddresses = import ../../../modules/addresses.nix;
  dynamicSshConfig = import ../../../modules/services/ssh/dynamic.nix { inherit lib allAddresses keys; };

  aiSshApp = pkgs.writeShellApplication {
    name = "ai-ssh";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ../../scripts/ai-ssh.sh;
  };
in
{
  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        IdentityFile = [
          "~/.ssh/id_ed25519"
          "~/.ssh/id_git_ed25519"
        ];
      };
    };

    extraConfig = builtins.readFile ../../assets/dotfiles/ssh/config + ''
      ${dynamicSshConfig}
    '';
  };

  home.packages = [ aiSshApp ];
}
