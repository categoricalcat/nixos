{
  lib,
  pkgs,
  ...
}:
let
  keys = import ../../../secrets/keys.nix;
  allAddresses = import ../../../modules/addresses.nix;
  dynamicSshConfig = import ../../../modules/ssh-dynamic.nix { inherit lib allAddresses keys; };

  ysshApp = pkgs.writeShellApplication {
    name = "yssh";
    text = builtins.readFile ./yssh.sh;
  };

  ysshWrappers = lib.concatMap (
    host:
    let
      hasPort = (host.ssh.listenPort or null) != null;
      validAliases = lib.filter (a: lib.attrByPath a.path null host != null) allAddresses.aliases;
      targets = map (a: "${host.hostName}.${a.suffix}") validAliases;
    in
    lib.optional (hasPort && targets != [ ]) (
      pkgs.writeShellScriptBin "ssh-${host.hostName}" ''
        exec ${lib.getExe ysshApp} "${host.hostName}" ${lib.escapeShellArgs targets} -- "$@"
      ''
    )
  ) (builtins.attrValues allAddresses.hosts);
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

  home.packages = ysshWrappers;
}
