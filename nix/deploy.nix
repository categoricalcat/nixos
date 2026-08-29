{
  self,
  inputs,
  ...
}:
let
  addresses = import ../modules/addresses.nix;
in
{
  flake = {
    deploy = {
      magicRollback = true;
      autoRollback = true;
      confirmTimeout = 30;
      nodes = {
        yifuwuqi = {
          hostname = addresses.hosts.yifuwuqi.network.tailscale.ipv4.host;
          sshOpts = [
            "-p"
            (toString addresses.hosts.yifuwuqi.ssh.listenPort)
          ];
          profiles.system = {
            user = "root";
            sshUser = "root";
            path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.yifuwuqi;
          };
        };

        yirukou = {
          hostname = addresses.hosts.yirukou.network.tailscale.ipv4.host;
          sshOpts = [
            "-p"
            (toString addresses.hosts.yirukou.ssh.listenPort)
          ];
          profiles.system = {
            user = "root";
            sshUser = "root";
            path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.yirukou;
          };
        };

        yitaishi = {
          hostname = addresses.hosts.yitaishi.network.tailscale.ipv4.host;
          sshOpts = [
            "-p"
            (toString addresses.hosts.yitaishi.ssh.listenPort)
          ];
          profiles.system = {
            user = "root";
            sshUser = "root";
            path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.yitaishi;
          };
        };

        yixiaoqing = {
          hostname = addresses.hosts.yixiaoqing.network.tailscale.ipv4.host;
          sshOpts = [
            "-p"
            (toString addresses.hosts.yixiaoqing.ssh.listenPort)
          ];
          profiles.system = {
            user = "root";
            sshUser = "root";
            path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.yixiaoqing;
          };
        };
      };
    };
  };

  perSystem =
    { system, ... }:
    {
      checks = inputs.deploy-rs.lib.${system}.deployChecks self.deploy;
    };
}
