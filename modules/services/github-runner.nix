{ config, pkgs, ... }:

{
  services.github-runners."nixos" = {
    enable = true;
    url = "https://github.com/categoricalcat/nixos";
    tokenFile = config.sops.secrets."tokens/github-runner-nixos".path;
    ephemeral = true;
    replace = true;
    extraLabels = [
      "self-hosted"
      "nixos"
      "fufuwuqi"
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
}
