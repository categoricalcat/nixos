# System packages configuration module

{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    ((emacsPackagesFor emacs-pgtk).emacsWithPackages (epkgs: [ epkgs.vterm ]))

    gcc
    gnumake
    killall

    # System utilities
    btop
    curl
    fastfetch
    stow
    tmux
    wget

    # Development tools
    deadnix
    dig
    direnv
    fd
    gh
    git
    k6
    nil
    nix-direnv
    nixfmt
    nftables
    rclone
    sops
    statix
    tree

    # Shell and related tools
    fzf
    starship
    zoxide

    bat
    brotli
    ethtool
    iftop
    iperf3
    kubectl
    ncdu
    nethogs
    nmap
    python3
    screen
    systemd
    tcpdump
    traceroute
    wireguard-tools
  ];
}
