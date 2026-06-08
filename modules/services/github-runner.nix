{
  config,
  pkgs,
  allAddresses,
  ...
}:

let
  internalHost = config.networking.hostName;
  repo = "categoricalcat/nixos";
  services = allAddresses.hosts.yifuwuqi.services;
in
{
  services.github-runners."nixos" = {
    enable = true;
    user = "nix-builder";
    group = "nogroup";
    url = "https://github.com/${repo}";
    tokenFile = config.sops.secrets."tokens/github-runner-nixos".path;
    replace = true;
    extraLabels = [
      "self-hosted"
    ];
    extraPackages = with pkgs; [
      bash
      coreutils
      curl
      git
      gnugrep
      gnused
      findutils
      gawk
      gzip
      jq
      nix
    ];
    extraEnvironment = {
      FORGEJO_INTERNAL_URL = "http://${internalHost}:${toString services.forgejo.httpPort}";
      WOODPECKER_INTERNAL_URL = "http://${internalHost}:${toString services.woodpecker.httpPort}";
      GITHUB_REPO = repo;
    };
  };

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
    owner = "nix-builder";
    group = "nogroup";
  };
}
