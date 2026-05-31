{ config, pkgs, ... }:

{
  services.hercules-ci-agent = {
    enable = true;
    settings = {
      clusterJoinTokenPath = config.sops.secrets."tokens/hercules-ci-cluster-join-token".path;
      binaryCachesPath = pkgs.writeText "binary-caches.json" "{}";
    };
  };

  sops.secrets."tokens/hercules-ci-cluster-join-token" = {
    owner = "hercules-ci-agent";
  };
}
