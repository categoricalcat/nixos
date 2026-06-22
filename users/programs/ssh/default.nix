{
  lib,
  inputs,
  ...
}:
let
  keys = import ../../../secrets/keys.nix;
  allAddresses = import ../../../modules/addresses.nix;
  dynamicSshConfig = import ../../../modules/ssh-dynamic.nix { inherit lib allAddresses keys; };
in
{
  services.ssh-agent.enable = true;

  programs.keychain = {
    enable = true;
    enableZshIntegration = true;
    keys = [
      "id_ed25519"
      "id_git_ed25519"
    ];
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = { };
    };

    extraConfig = builtins.readFile "${inputs.thefiles}/.ssh/config" + ''
      ${dynamicSshConfig}
    '';
  };
}
