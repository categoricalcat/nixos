# Centralised Podman / container infrastructure
# Provides: backend, podman daemon, storage, registries,
# container defaults, volume directory, and CLI tools.

{
  pkgs,
  addresses,
  ...
}:

{
  # ── Backend ────────────────────────────────────────────────────────
  virtualisation = {
    oci-containers.backend = "podman";

    podman = {
      enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings = {
        dns_enabled = false;
        ipv6_enabled = true;
        mtu = 1492;
      };

      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ];
      };
    };

    containers = {
      enable = true;

      storage.settings = {
        storage = {
          driver = "overlay";
          runroot = "/run/containers/storage";
          graphroot = "/var/lib/containers/storage";
          options.overlay.mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs";
        };
      };

      registries = {
        search = [
          "docker.io"
          "quay.io"
          "ghcr.io"
        ];
      };

      containersConf.settings = {
        containers = {
          dns_servers = [
            addresses.network.lan.ipv4.host
          ];
          log_driver = "journald";
          log_size_max = 10485760; # 10MB in bytes (10 * 1024 * 1024)
          default_ulimits = [
            "nofile=65536:65536"
          ];
        };

        network = {
          default_subnet_pools = addresses.containers.subnetPools;
        };
      };
    };
  };

  # ── Dedicated volume storage ───────────────────────────────────────
  systemd.tmpfiles.rules = [
    "d /var/lib/container-volumes 0770 root podman -"
  ];

  # ── User access ────────────────────────────────────────────────────
  users.users.workd.extraGroups = [ "podman" ];

  # ── CLI tools ──────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    buildah
    dive
    podman-compose
    podman-tui
    skopeo
  ];
}
