{
  addresses,
  pkgs,
  ...
}:
{
  imports = [
    ./networking/firewall.nix
    ../../modules/networking/sinkhole.nix
    ../../modules/networking/gateway-failover.nix
    ./networking/interfaces/eno1.nix
    ./networking/interfaces/enp4s0.nix
    ./networking/interfaces/wlp2s0.nix
    ./networking/sysctl.nix
  ];

  services.resolved = {
    enable = true;
    settings.Resolve.DNSStubListener = "no";
  };

  networking = {
    inherit (addresses) hostName;

    nameservers = addresses.dns.systemNameservers;

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    wait-online.enable = true;

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
