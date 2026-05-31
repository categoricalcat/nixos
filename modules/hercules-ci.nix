{ config, ... }:

{
  services.hercules-ci-agent = {
    enable = true;
    settings = {
      clusterJoinTokenPath = config.sops.secrets."tokens/hercules-ci-cluster-join-token".path;
    };
  };

  sops.secrets."tokens/hercules-ci-cluster-join-token" = {
    owner = "hercules-ci-agent";
  };
}
