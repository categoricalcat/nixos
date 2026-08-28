# System packages configuration module

{ pkgs, ... }:
let
  wrappers = import ../packages/wrappers.nix { inherit pkgs; };
in
{
  environment.systemPackages =
    (with pkgs; [
      cursor-cli

      gcc
      gnumake
      killall
      zsh
      cloudflared

      # System utilities
      # rocmSupport=true patches in the rpath so btop dlopens librocm_smi64
      # and shows the AMD iGPU. Without it, btop builds CPU-only.
      amdgpu_top
      curl
      stow
      wget

      # Development tools
      deadnix # Nix dead code locator
      dig
      fd
      gh
      git
      k6
      nil # Nix language server
      nixd # Nix language server (with statix/deadnix support)
      nixfmt # Official RFC-166 Nix formatter
      nixpkgs-hammering # Linter for Nixpkgs packages
      direnv # Environment switcher for shell
      nix-update # Swiss-knife for updating nix packages
      nix-init # Generator for Nix packages from URLs
      comma # Run software without installing it (, <pkg>)
      nftables
      rclone
      sops
      statix # Lints and suggestions for Nix
      tree
      treefmt

      # Shell and related tools
      shellcheck
      shfmt
      shellharden
      bubblewrap
      bat
      brotli
      ethtool
      iftop
      iperf3
      jq
      kubectl
      ncdu
      nethogs
      nmap
      python3
      screen
      systemd
      tcpdump
      traceroute
      # pkgs.bitwarden-cli
      ripgrep
    ])
    ++ (builtins.attrValues wrappers);

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 2d --keep 2";
    flake = "/home/yi/the.files/nixos";
  };
}
