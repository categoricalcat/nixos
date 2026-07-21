{
  addresses,
  allAddresses,
  ...
}:
{
  imports = [
    ../../modules/services/ai/llama-swap.nix
    ../../modules/services/tailscale.nix
    # ../../modules/services/netbird.nix
    ../../modules/services/lan-mouse.nix
  ];

  services.llama-swap-amdgpu = {
    enable = false;
    rocmTargets = [ "gfx1100" ];
    rocmOverrideGfx = null;
    uma = false;
    # Yifuwuqi's APU fix hard-coded card0/renderD128; allow the common dGPU
    # numbering variants here so the RPC worker is not coupled to that host.
    drmDevices = [
      "/dev/dri/card0"
      "/dev/dri/renderD128"
      "/dev/dri/card1"
      "/dev/dri/renderD129"
    ];
    rpcServer = {
      enable = true;
      listenAddress = addresses.network.vpn.ipv4.host;
      port = 50052;
      cacheDir = "/var/cache/llama-rpc-server";
      # Expose ONLY the discrete RX 7900 XTX. The 7700X has a gfx1036 iGPU
      # that ROCm enumerates alongside it, but llama-cpp here is built with
      # rocmGpuTargets = [ "gfx1100" ] — dispatching a tensor onto the
      # iGPU would hit a missing-kernel address and SEGV the worker, which
      # is exactly what was observed during the first real client load.
      devices = [ "ROCm0" ];
    };
  };

  networking.firewall.interfaces.${addresses.network.vpn.interface}.allowedTCPPorts = [ 50052 ];

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
