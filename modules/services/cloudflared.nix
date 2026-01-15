{ config, ... }:

{
  virtualisation.oci-containers.backend = "podman";

  users.groups.cloudflared = { };
  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
  };

  sops.templates."cloudflared.env".content = ''
    TUNNEL_TOKEN=${config.sops.placeholder."tokens/cloudflared"}
  '';

  virtualisation.oci-containers.containers.cloudflared = {
    autoStart = true;
    image = "cloudflare/cloudflared:latest";
    # Run as non-root; map container UID to host user `cloudflared` group
    user = "${toString config.users.users.cloudflared.uid}:${toString config.users.groups.cloudflared.gid}";
    extraOptions = [
      "--network=host"
      "--pull=newer"
    ];
    environmentFiles = [
      config.sops.templates."cloudflared.env".path
    ];
    cmd = [
      "tunnel"
      "--no-autoupdate"
      "run"
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

  sops.secrets."tokens/cloudflared" = { };
}
