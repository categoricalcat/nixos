{
  allAddresses,
  ...
}:
{
  imports = [
    ../../modules/services/tailscale.nix
    ../../modules/services/lan-mouse.nix
  ];

  services.lan-mouse.settings = {
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
}
