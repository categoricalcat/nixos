{
  config,
  lib,
  pkgs,
  addresses,
  ...
}:

let
  inherit (config.yi.maintenance) slots;

  isLocalImage =
    c: c.imageFile != null || c.imageStream != null || lib.hasPrefix "localhost/" c.image;
in
{
  imports = [
    {
      options.virtualisation.oci-containers.containers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { config, ... }:
            {
              labels = lib.mkIf (!isLocalImage config) {
                "io.containers.autoupdate" = lib.mkDefault "registry";
              };
            }
          )
        );
      };
    }
  ];

  assertions = lib.mapAttrsToList (name: c: {
    assertion = isLocalImage c || builtins.match "[^/]+[.:][^/]*/.+" c.image != null;
    message = "virtualisation.oci-containers.containers.${name}: image `${c.image}` must be fully qualified (registry/name:tag) for podman auto-update";
  }) config.virtualisation.oci-containers.containers;

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
        dates = slots.containerPrune.calendar;
        flags = [ "--all" ];
      };
    };

    containers = {
      enable = true;

      storage = {
        settings = {
          storage = {
            driver = "overlay";
            options.overlay.mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs";
          };
        };

        rootful.settings = {
          storage = {
            runroot = "/run/containers/storage";
            graphroot = "/var/lib/containers/storage";
          };
        };
      };

      registries.settings = {
        unqualified-search-registries = [
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

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/container-volumes 0770 root podman -"
    ];
    timers = {
      podman-auto-update = {
        wantedBy = [ "timers.target" ];
        timerConfig = slots.podmanAutoUpdate.timerConfig // {
          OnCalendar = [
            ""
            slots.podmanAutoUpdate.calendar
          ];
        };
      };
      podman-prune = {
        inherit (slots.containerPrune) timerConfig;
      };
    };
    services.podman-prune.after = [ "podman-auto-update.service" ];
  };

  environment.systemPackages = with pkgs; [
    buildah
    dive
    podman-compose
    podman-tui
    skopeo
  ];
}
