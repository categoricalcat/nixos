_: {
  perSystem =
    { pkgs, config, ... }:
    let
      rustPkgs = with pkgs; [
        cargo
        rustc
        rustfmt
        clippy
        rust-analyzer
      ];

      defaultShell = pkgs.mkShell {
        packages = rustPkgs;
        shellHook = ''
          export RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}"
          ${config.pre-commit.devShell.shellHook or ""}
        '';
      };

      sandboxShell = pkgs.mkShell {
        packages = rustPkgs ++ [
          pkgs.bubblewrap
          pkgs.zsh
          pkgs.unzip
          pkgs.git
          pkgs.sudo
        ];
        shellHook = ''
          echo "Entering ephemeral sandbox as 'none'..."
          export RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}"

          # Use bubblewrap to map to none and create a tmpfs home
          exec bwrap \
            --unshare-user --uid 65534 --gid 65534 \
            `# 1. Minimal system dependencies (strictly read-only)` \
            --ro-bind /nix/store /nix/store \
            --ro-bind /etc /etc \
            --bind /home/none /home/none \
            --dev /dev \
            --proc /proc \
            `# 3. Environment and startup` \
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

      #packages.default = defaultShell;
      #packages.sandbox = sandboxShell;
    };
}
