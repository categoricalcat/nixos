{
  addresses,
  ...
}:
{
  imports = [
    ../../modules/services/ai/llama-swap.nix
    ../../modules/services/tailscale.nix
    # ../../modules/services/zerotier.nix
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
      # Bind to this host's actual tailscale IP from the address registry,
      # not a hardcoded value, so a stale IP can't desync the rpc server
      # from the tailnet again.
      listenAddress = addresses.network.tailscale.ipv4.host;
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

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 50052 ];

  services.lan-mouse.settings = {
    release_bind = [
      "KeyRightCtrl"
      "KeyRightalt"
    ];
    clients = [
      {
        position = "right";
        hostname = "yixiaoqing";
        activate_on_startup = true;
        ips = [ (import ../../modules/addresses.nix).hosts.yixiaoqing.network.tailscale.ipv4.host ];
      }
    ];
  };
}
