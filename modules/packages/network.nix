# Network diagnostic utilities module

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    brotli
    ethtool
    iftop
    iperf3
    nethogs
    nmap
    tcpdump
    traceroute
    nftables
  ];
}
