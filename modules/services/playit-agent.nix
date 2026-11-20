{
  config,
  ...
}:

{

  # Pinned so the container `user` renders at eval time (unpinned accounts
  # render "null:null" and the container silently runs as root).
  users.groups.playit.gid = 347;
  users.users.playit = {
    isSystemUser = true;
    uid = 347;
    group = "playit";
  };

  virtualisation.oci-containers.containers.playit-agent = {
    autoStart = true;
    image = "ghcr.io/playit-cloud/playit-agent:latest";
    user = "${toString config.users.users.playit.uid}:${toString config.users.groups.playit.gid}";
    extraOptions = [
      "--pull=newer"
    ];
    environmentFiles = [
      config.sops.templates."playit-agent.env".path
    ];
    environment = {
      NO_AUTOUPDATE = "true";
    };
  };

  sops.templates."playit-agent.env".content = config.sops.placeholder."tokens/playit-agent";

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

  sops.secrets."tokens/playit-agent" = { };
}
