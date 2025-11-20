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
    nixfmt-rfc-style
    nftables
    rclone
    sops
    statix
    tree
    vscode-fhs

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
    cockpit
    ethtool
    iftop
    iperf3
    kubectl
    maple-mono.NF-CN
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
