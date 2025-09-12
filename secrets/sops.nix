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
    "tokens/cloudflared" = {
      mode = "0640";
      owner = "cloudflared";
      group = "cloudflared";
      path = "/etc/cloudflared/token";
    };
    "tokens/playit-agent" = {
      mode = "0640";
      owner = "playit";
      group = "playit";
      path = "/etc/playit/token";
    };
  };

  environment.variables.SOPS_AGE_KEY_FILE = "/etc/nixos/secrets/key.txt";
  systemd.globalEnvironment.SOPS_AGE_KEY_FILE = "/etc/nixos/secrets/key.txt";

  users.groups.cloudflared = { };
  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
  };

  users.groups.playit = { };
  users.users.playit = {
    isSystemUser = true;
    group = "playit";
  };
}
