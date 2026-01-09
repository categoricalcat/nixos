{ config, ... }:

{
  virtualisation.oci-containers.backend = "podman";

  users.groups.playit = { };
  users.users.playit = {
    isSystemUser = true;
    group = "playit";
  };

  virtualisation.oci-containers.containers.playit-agent = {
    autoStart = true;
    image = "ghcr.io/playit-cloud/playit-agent:latest";
    user = "${toString config.users.users.playit.uid}:${toString config.users.groups.playit.gid}";
    extraOptions = [
      "--network=host"
      "--pull=newer"
    ];
    environmentFiles = [
      "${config.sops.secrets."tokens/playit-agent".path}"
    ];
    environment = {
      NO_AUTOUPDATE = "true";
    };
  };

  systemd.services."podman-playit-agent" = {
    wants = [
      "network-online.target"
      "sops-nix.service"
    ];
    after = [
      "network-online.target"
      "sops-nix.service"
    ];
  };

  sops.secrets."tokens/playit-agent" = {
    mode = "0640";
    owner = "playit";
    group = "playit";
    path = "/etc/playit/token";
  };
}
