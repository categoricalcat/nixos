{
  addresses,
  allAddresses,
  ...
}:
{
  imports = [
    ../../modules/services/tailscale.nix
    ../../modules/services/lan-mouse.nix
    ../../modules/services/nordvpn.nix
    ../../modules/services/ai/llama-cpp.nix
  ];

  networking.firewall.interfaces.${addresses.network.vpn.interface}.allowedTCPPorts = [
    addresses.services.llama-cpp.port
  ];

  services = {
    llama-cpp-node = {
      enable = true;
      backend = "vulkan";
      listenAddresses = [
        "127.0.0.1"
        addresses.network.vpn.ipv4.host
      ];
    };

    lan-mouse.settings = {
      release_bind = [
        "KeyRightCtrl"
        "KeyRightalt"
      ];
      right = {
        hostname = "${allAddresses.hosts.yixiaoqing.hostName}.${allAddresses.hosts.yixiaoqing.network.vpn.domain}";
        activate_on_startup = true;
        ips = [ allAddresses.hosts.yixiaoqing.network.vpn.ipv4.host ];
      };
    };
  };
}
