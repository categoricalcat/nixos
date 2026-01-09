# sops.nix
_: {
  config = {
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    sops.defaultSopsFile = "/etc/nixos/secrets/secrets.yaml";
    sops.age.keyFile = "/etc/nixos/secrets/key.txt";
    sops.validateSopsFiles = false;

    environment.variables.SOPS_AGE_KEY_FILE = "/etc/nixos/secrets/key.txt";
    systemd.globalEnvironment.SOPS_AGE_KEY_FILE = "/etc/nixos/secrets/key.txt";
  };
}
