{ config, pkgs, ... }:

{
  services.github-runners."nixos" = {
    enable = true;
    url = "https://github.com/categoricalcat/nixos";
    tokenFile = config.sops.secrets."tokens/github-runner-nixos".path;
    replace = true;
    extraLabels = [
      "self-hosted"
    ];
    extraPackages = with pkgs; [
      bash
      coreutils
      git
      gnugrep
      gnused
      findutils
      gawk
      gzip
    ];
  };

  users.groups.github-runner = { };
  users.users.github-runner = {
    isSystemUser = true;
    group = "github-runner";
  };

  # Ensure runner starts after network and secrets are ready
  systemd.services."github-runner-nixos" = {
    wants = [
      "network-online.target"
      "sops-nix.service"
    ];
    after = [
      "network-online.target"
      "sops-nix.service"
    ];
  };

  sops.secrets."tokens/github-runner-nixos" = {
    mode = "0640";
    owner = "github-runner";
    group = "github-runner";
  };
}
