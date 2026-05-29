{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      config,
      ...
    }:
    let
      unstablePkgs = import ../modules/nixpkgs-unstable.nix { inherit inputs pkgs; };
      rustPkgs = with unstablePkgs; [
        cargo
        rustc
        rustfmt
        clippy
        rust-analyzer
        nix-tree
        nix-inspect
      ];

      defaultShell = pkgs.mkShell {
        packages = rustPkgs;
        shellHook = ''
          export RUST_SRC_PATH="${unstablePkgs.rustPlatform.rustLibSrc}"
          ${config.pre-commit.devShell.shellHook or ""}
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
          export RUST_SRC_PATH="${unstablePkgs.rustPlatform.rustLibSrc}"

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
