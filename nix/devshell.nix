{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    let
      _pkgs = pkgs;
    in
    let
      pkgs = import ../modules/nixpkgs-unstable.nix {
        inherit inputs;
        pkgs = _pkgs;
      };
      rustPkgs = with pkgs; [
        cargo
        rustc
        rustfmt
        clippy
        rust-analyzer
        nix-tree
        nix-inspect
      ];

      nixosRebuildWrapper = pkgs.writeShellScriptBin "nixos-rebuild" ''
        exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild --override-input thefiles git+file:///home/yi/the.files "$@"
      '';

      nixDevPkgs = with pkgs; [
        statix # Lints and suggestions for Nix
        deadnix # Nix dead code locator
        nixpkgs-hammering # Linter for Nixpkgs packages
        nil # Nix language server
        nixd # Nix language server (with statix/deadnix support)
        nixfmt # Official RFC-166 Nix formatter
        nh # Nix Helper - nicer CLI for nixos-rebuild
        direnv # Environment switcher for shell
        nix-update # Swiss-knife for updating nix packages
        nix-init # Generator for Nix packages from URLs
        comma # Run software without installing it (, <pkg>)
      ];

      defaultShell = pkgs.mkShell {
        packages = rustPkgs ++ nixDevPkgs ++ [ nixosRebuildWrapper ];
        shellHook = ''
          export RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}"
        '';
      };

      sandboxShell = pkgs.mkShell {
        packages = rustPkgs ++ [
          pkgs.bubblewrap
          pkgs.zsh
          pkgs.unzip
          pkgs.git
        ];
        shellHook = ''
          echo "Entering ephemeral sandbox as 'none'..."
          export RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}"

          exec bwrap \
            --unshare-user --uid 65534 --gid 65534 \
            --unshare-pid \
            --die-with-parent \
            `# Filesystem` \
            --ro-bind /nix/store /nix/store \
            --ro-bind /etc/resolv.conf /etc/resolv.conf \
            --ro-bind /etc/ssl /etc/ssl \
            --ro-bind /etc/static /etc/static \
            --bind /home/none /home/none \
            --dev /dev \
            --proc /proc \
            --tmpfs /tmp \
            `# Environment` \
            --setenv HOME /home/none \
            --setenv USER none \
            --chdir /home/none \
            ${pkgs.zsh}/bin/zsh
        '';
      };
    in
    {
      devShells.default = defaultShell;
      devShells.sandbox = sandboxShell;

      packages.default = defaultShell;
      packages.sandbox = sandboxShell;
    };
}
