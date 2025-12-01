# sops.nix
{ config, lib, ... }:
{
  options.services.nix-access-tokens.enable = lib.mkEnableOption "GitHub access tokens for Nix";

  config = {
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    sops.defaultSopsFile = "/etc/nixos/secrets/secrets.yaml";
    sops.age.keyFile = "/etc/nixos/secrets/key.txt";
    sops.validateSopsFiles = false;

    sops.secrets = {
      "passwords/fufud" = {
        mode = "0600";
        owner = "fufud";
        group = "fufud";
      };
      "passwords/workd" = {
        mode = "0600";
        owner = "workd";
        group = "workd";
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
      "tokens/github-runner-nixos" = {
        mode = "0640";
        owner = "github-runner";
        group = "github-runner";
      };
      "joplin-env" = {
        mode = "0600";
        owner = "joplin";
        group = "joplin";
      };
    }
    // lib.optionalAttrs config.services.nix-access-tokens.enable {
      "github-token" = {
        mode = "0440";
      };
    };

    sops.templates = lib.mkIf config.services.nix-access-tokens.enable {
      "nix-access-tokens" = {
        content = ''
          access-tokens = github.com=${config.sops.secrets."github-token".placeholder}
        '';
        mode = "0440";
      };
    };

    environment.variables.SOPS_AGE_KEY_FILE = "/etc/nixos/secrets/key.txt";
    systemd.globalEnvironment.SOPS_AGE_KEY_FILE = "/etc/nixos/secrets/key.txt";

    users.groups = {
      cloudflared = { };
      playit = { };
      github-runner = { };
      joplin = { };
    };

    users.users = {
      joplin = {
        isSystemUser = true;
        group = "joplin";
      };
      cloudflared = {
        isSystemUser = true;
        group = "cloudflared";
      };
      playit = {
        isSystemUser = true;
        group = "playit";
      };
      github-runner = {
        isSystemUser = true;
        group = "github-runner";
      };
    };
  };
}
