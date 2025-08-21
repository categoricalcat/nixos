# sops.nix
_:
{
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.defaultSopsFile = "/etc/nixos/secrets/secrets.yaml";
  sops.age.keyFile = "/etc/nixos/secrets/key.txt";
  sops.validateSopsFiles = false;

  sops.secrets = {
    "passwords/fufud" = {
      mode = "0600";
      owner = "fufud";
      group = "users";
    };
    "passwords/workd" = {
      mode = "0600";
      owner = "workd";
      group = "users";
    };
  };
}
