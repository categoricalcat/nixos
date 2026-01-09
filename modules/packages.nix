# System packages configuration module

{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    emacs
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

    # Container tools (Podman)
    buildah
    dive
    podman-compose
    podman-tui
    skopeo

    # Security tools
    google-authenticator

    # Shell and related tools
    fzf
    starship
    zoxide
    zsh
    zsh-autosuggestions
    zsh-history-substring-search
    zsh-syntax-highlighting

    bat
    brotli
    gzip
    ncompress
    cockpit
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
