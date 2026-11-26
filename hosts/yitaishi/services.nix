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
    ../../modules/services/ai/sd-cpp.nix
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

    # The only client is `sd-cpp.aset.love` on yirukou, so the listener and the
    # unit's own address filter both name that one peer. `llama-cpp-node` above
    # cannot be narrowed the same way: `llama-server` dials HuggingFace when it
    # loads a preset model, so an address filter would break its fetch.
    sd-cpp-node = {
      enable = true;
      backend = "vulkan";
      listenAddress = addresses.network.vpn.ipv4.host;
      allowedClients = [ allAddresses.hosts.yirukou.network.vpn.ipv4.host ];
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
