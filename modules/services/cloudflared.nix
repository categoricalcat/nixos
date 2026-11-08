{
  config,
  addresses,
  lib,
  ...
}:

let
  network = addresses.containers.cloudflared.network;
in
{
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
    image = "docker.io/cloudflare/cloudflared:latest";
    # Run as non-root; map container UID to host user `cloudflared` group
    user = "${toString config.users.users.cloudflared.uid}:${toString config.users.groups.cloudflared.gid}";
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
    networks = [ network.name ];
    extraOptions = [ "--ip=${network.ipv4.host}" ];
  };

  systemd.services."podman-cloudflared" = {
    serviceConfig.ExecStartPre = lib.mkBefore [
      "${config.virtualisation.podman.package}/bin/podman network create --ignore --driver bridge --interface-name ${network.interface} --subnet ${network.ipv4.cidr} --gateway ${network.ipv4.gateway} ${network.name}"
    ];
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
