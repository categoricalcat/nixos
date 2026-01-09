{ config, ... }:

{
  virtualisation.oci-containers.backend = "podman";

  users.groups.cloudflared = { };
  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
  };

  virtualisation.oci-containers.containers.cloudflared = {
    autoStart = true;
    image = "cloudflare/cloudflared:latest";
    # Run as non-root; map container UID to host user `cloudflared` group
    user = "${toString config.users.users.cloudflared.uid}:${toString config.users.groups.cloudflared.gid}";
    extraOptions = [
      "--network=host"
      "--pull=newer"
    ];
    volumes = [
      "${config.sops.secrets."tokens/cloudflared".path}:/token:ro,U"
    ];
    cmd = [
      "tunnel"
      "--no-autoupdate"
      "run"
      "--token-file"
      "/token"
    ];
    environment = {
      NO_AUTOUPDATE = "true";
    };
  };

  systemd.services."podman-cloudflared" = {
    wants = [
      "network-online.target"
      "sops-nix.service"
    ];
    after = [
      "network-online.target"
      "sops-nix.service"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /etc/cloudflared 0750 root root -"
  ];

  sops.secrets."tokens/cloudflared" = {
    mode = "0640";
    owner = "cloudflared";
    group = "cloudflared";
    path = "/etc/cloudflared/token";
  };
}
