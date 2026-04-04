{
  config,
  lib,
  allAddresses,
  ...
}:

let
  cfg = config.distributedBuilds;
  serverHost = allAddresses.hosts.yifuwuqi;
  clientHost = allAddresses.hosts.yixiaoqing;
  serverAddress = serverHost.network.tailscale.ipv4.host;
  clientAddress = clientHost.network.tailscale.ipv4.host;
in
{
  options.distributedBuilds = {
    enable = lib.mkEnableOption "distributed Nix builds";

    role = lib.mkOption {
      type = lib.types.enum [
        "none"
        "client"
        "server"
      ];
      default = "none";
      description = "Whether this host acts as the distributed build client or server.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.role != "none";
            message = "distributedBuilds.enable requires distributedBuilds.role to be `client` or `server`.";
          }
          {
            assertion = cfg.role != "server" || config.services.openssh.enable;
            message = "distributedBuilds server mode requires services.openssh.enable.";
          }
          {
            assertion = cfg.role != "server" || lib.elem "yi" config.nix.settings.trusted-users;
            message = "distributedBuilds server mode requires nix.settings.trusted-users to include `yi`.";
          }
        ];
      }

      (lib.mkIf (cfg.role == "client") {
        nix = {
          distributedBuilds = lib.mkDefault true;

          buildMachines = lib.mkDefault [
            {
              hostName = serverAddress;
              system = "x86_64-linux";
              maxJobs = 15;
              speedFactor = 3;
              protocol = "ssh-ng";
              supportedFeatures = [
                "nixos-test"
                "benchmark"
                "big-parallel"
                "kvm"
              ];
              sshUser = "yi";
              sshKey = "/home/yi/.ssh/id_ed25519";
            }
          ];

          settings = {
            builders-use-substitutes = lib.mkDefault true;
            connect-timeout = lib.mkDefault 5;
          };
        };

        programs.ssh.extraConfig = lib.mkAfter ''
          Host ${serverAddress}
            Port ${toString serverHost.ssh.listenPort}
        '';
      })

      (lib.mkIf (cfg.role == "server") {
        services.openssh.extraConfig = lib.mkAfter ''
          Match User yi Address ${clientAddress}
            AuthenticationMethods publickey
        '';
      })
    ]
  );
}
