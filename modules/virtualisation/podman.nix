{
  config,
  lib,
  pkgs,
  addresses,
  ...
}:

let
  inherit (config.yi.maintenance) slots;

  dnsServers = [
    addresses.network.lan.ipv4.host
  ];

  isLocalImage =
    c: c.imageFile != null || c.imageStream != null || lib.hasPrefix "localhost/" c.image;

  # Unit-level sandboxing safe for rootful podman: the process tree (podman,
  # conmon, crun, netavark) still needs capabilities, namespaces, setuid file
  # modes during layer extraction, host /proc/sys writes for bridge setup,
  # and real /dev (fuse-overlayfs, /dev/net/tun), so the strict
  # `systemdHardening` set from modules/common.nix cannot apply here.
  # No ProtectHostname: observed 2026-11-21 (systemd 262, podman 6.1.4) that
  # it makes every container create fail in crun with "sethostname:
  # Operation not permitted" — the runtime cannot set the container hostname.
  podmanUnitHardening = {
    PrivateTmp = true;
    ProtectHome = true;
    ProtectClock = true;
    ProtectKernelLogs = true;
    RestrictRealtime = true;
    LockPersonality = true;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK"
      "AF_PACKET"
    ];
  };
in
{
  imports = [
    {
      options.virtualisation.oci-containers.containers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule (
            { config, ... }:
            {
              options.rootReason = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Why this container may run host-root processes";
              };
              config = {
                labels = lib.mkIf (!isLocalImage config) {
                  "io.containers.autoupdate" = lib.mkDefault "registry";
                };
                # `--rm` makes Podman store the container as volatile, which
                # cAdvisor 0.56.2 cannot resolve. The unit already removes the
                # container in preStart and postStop.
                autoRemoveOnStop = lib.mkDefault false;
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
          dns_servers = dnsServers;
          log_driver = "journald";
          log_size_max = 10485760; # 10MB in bytes (10 * 1024 * 1024)
          default_ulimits = [
            "nofile=65536:65536"
          ];
        };

        network = {
          dns_servers = dnsServers;
          default_subnet_pools = addresses.containers.subnetPools;
          pasta_options = [
            "--mtu"
            "1500"
          ];
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
    services = lib.mkMerge [
      { podman-prune.after = [ "podman-auto-update.service" ]; }
      (lib.concatMapAttrs (name: _: {
        "podman-${name}".serviceConfig = podmanUnitHardening;
      }) config.virtualisation.oci-containers.containers)
    ];
  };
}
