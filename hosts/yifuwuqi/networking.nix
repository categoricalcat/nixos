{
  addresses,
  pkgs,
  ...
}:
{
  imports = [
    ./networking/firewall.nix
    ../../modules/networking/sinkhole.nix
    ../../packages/gateway-failover
    ./networking/interfaces/eno1.nix
    ./networking/interfaces/enp4s0.nix
    ./networking/interfaces/wlp2s0.nix
    ./networking/sysctl.nix
  ];

  networking = {
    inherit (addresses) hostName;

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;
  };

  services.resolved.settings.Resolve = {
    DNSStubListener = "yes";
    DNSStubListenerExtra = addresses.dns.stubListenAddresses;
  };

  systemd.network = {
    enable = true;
    wait-online = {
      enable = true;
      # r8169 1Gbps->100Mbps PHY downshift + IPv6 DAD took 14.9s on cold boot;
      # 25s clears that window cleanly while staying well below the 120s default.
      timeout = 25;
    };
  };

  # Subnet routing forwards tunnel traffic through these NICs, and tailscaled
  # warns on start until the kernel can coalesce it. Same service as on
  # yirukou (hosts/yirukou/networking/wans.nix).
  systemd.services.tailscale-udp-gro = {
    description = "Enable UDP GRO forwarding for Tailscale";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.ethtool}/bin/ethtool -K ${addresses.network.lan.interface} rx-udp-gro-forwarding on rx-gro-list off || true
      ${pkgs.ethtool}/bin/ethtool -K ${addresses.network.secondary.interface} rx-udp-gro-forwarding on rx-gro-list off || true
    '';
  };
}
