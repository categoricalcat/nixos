{
  config,
  pkgs,
  allAddresses,
  ...
}:

let
  repo = "categoricalcat/nixos";
  forgejoRepo = "yi/nixos";
  services = allAddresses.hosts.yifuwuqi.services;

  # Idiomatic Nix: generate a script to export our dynamic environment variables
  # to the GitHub Actions runner environment.
  setupCiEnv = pkgs.writeShellScriptBin "setup-ci-env" ''
    echo "FORGEJO_INTERNAL_URL=https://${services.forgejo.domain}" >> "$GITHUB_ENV"
    echo "WOODPECKER_INTERNAL_URL=https://${services.woodpecker.domain}" >> "$GITHUB_ENV"
    echo "FORGEJO_REPO=${forgejoRepo}" >> "$GITHUB_ENV"
    echo "GITHUB_REPO=${repo}" >> "$GITHUB_ENV"
  '';
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
      setupCiEnv
    ];
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
