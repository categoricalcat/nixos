# sops.nix
{
  config,
  lib,
  ...
}:
let
  hasRegularSopsSecrets = lib.any (secret: !secret.neededForUsers) (
    lib.attrValues config.sops.secrets
  );
  hasSeparateHome = builtins.hasAttr "/home" config.fileSystems;
in
{
  config = {
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # This encrypted file is kept outside the flake source, so use the runtime path.
    sops.defaultSopsFile = "/etc/nixos/secrets/secrets.yaml";
    sops.age.keyFile = "/etc/nixos/secrets/key.txt";
    sops.useSystemdActivation = true;
    sops.validateSopsFiles = false;

    environment.variables.SOPS_AGE_KEY_FILE = "/etc/nixos/secrets/key.txt";
    systemd.globalEnvironment.SOPS_AGE_KEY_FILE = "/etc/nixos/secrets/key.txt";

    # Some hosts mount /home separately while /etc/nixos points into that tree.
    systemd.services.sops-install-secrets = lib.mkIf (hasRegularSopsSecrets && hasSeparateHome) {
      wants = [ "home.mount" ];
      after = [ "home.mount" ];
    };
  };
}
