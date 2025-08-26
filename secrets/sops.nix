# sops.nix
_: {
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
    "tokens/cloudflare-ddclient" = {
      mode = "0400";
      owner = "ddclient";
      group = "ddclient";
    };
    "tokens/cloudflare-acme" = {
      mode = "0400";
      owner = "acme";
      group = "acme";
    };

    # FRP shared token for client/server
    "tokens/frp" = {
      mode = "0400";
      owner = "root";
      group = "root";
    };
  };
}
