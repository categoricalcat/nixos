{ lib, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      rustPkgs = [
        pkgs.cargo
        pkgs.rustc
        pkgs.rustfmt
        pkgs.clippy
        pkgs.rust-analyzer
        pkgs.nix-tree
        pkgs.nix-inspect
      ];

      nixosRebuildWrapper = pkgs.writeShellApplication {
        name = "nixos-rebuild";
        text = ''
          exec ${lib.getExe pkgs.nixos-rebuild} "$@"
        '';
      };

      wrappers = import ../packages/wrappers.nix { inherit pkgs; };

      nixDevPkgs = [
        pkgs.statix # Lints and suggestions for Nix
        pkgs.deadnix # Nix dead code locator
        pkgs.nixf-diagnose # Nix semantic linter and auto-fixer
        pkgs.shellcheck # Shell linter
        pkgs.shfmt # Shell formatter
        pkgs.shellharden # Shell syntax hardener and auto-quoter
        config.packages.eslint-env # Repo-wide TS linter (eslint + perfectionist)
        config.treefmt.build.wrapper # Universal multi-file formatter (wrapped with flake config)
        pkgs.nixpkgs-hammering # Linter for Nixpkgs packages
        pkgs.nil # Nix language server
        pkgs.nixd # Nix language server (with statix/deadnix support)
        pkgs.nixfmt # Official RFC-166 Nix formatter
        pkgs.direnv # Environment switcher for shell
        pkgs.nix-update # Swiss-knife for updating nix packages
        pkgs.nix-init # Generator for Nix packages from URLs
        pkgs.comma # Run software without installing it (, <pkg>)
        pkgs.nvd # Package version diff tool for Nix store paths
        pkgs.deploy-rs # Multi-profile NixOS deployment tool
        pkgs.fzf # Command-line fuzzy finder
        pkgs.jq # Command-line JSON processor
        pkgs.dnsx # Fast and multi-purpose DNS toolkit
        pkgs.curl # Transfer data with URLs
      ];

      defaultShell = pkgs.mkShell {
        packages =
          rustPkgs
          ++ nixDevPkgs
          ++ (builtins.attrValues wrappers)
          ++ [
            pkgs.zsh
            nixosRebuildWrapper
          ]
          ++
            map
              (
                name:
                pkgs.writeShellApplication {
                  inherit name;
                  text = builtins.readFile (./scripts + "/${name}.sh");
                }
              )
              [
                "inspect"
                "host-tree"
                "host-size"
                "host-diff"
                "host-dead"
                "dns-warm"
                "host-why"
                "host-audit"
              ];
        shellHook = ''
          ${config.pre-commit.installationScript}
          export RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}"
          # `nix develop` can start in any subdir (or outside the repo via an
          # explicit flake ref); anchor at the flake root, not cwd.
          hook_root=$PWD
          while [ "$hook_root" != / ] && [ ! -e "$hook_root/flake.nix" ]; do
            hook_root=$(dirname "$hook_root")
          done
          if [ -d "$hook_root/packages/firecrawl-mcp" ] && { [ ! -e "$hook_root/packages/firecrawl-mcp/node_modules" ] || [ -L "$hook_root/packages/firecrawl-mcp/node_modules" ]; }; then
            ln -sfn ${config.packages.firecrawl-mcp.nodeModules}/node_modules "$hook_root/packages/firecrawl-mcp/node_modules"
          fi
          if [ -z "$DIRENV_IN_ENVRC" ]; then
            exec zsh
          fi
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
            ${lib.getExe pkgs.zsh}
        '';
      };
    in
    {
      devShells.default = defaultShell;
      devShells.sandbox = sandboxShell;

      packages = wrappers;
    };
}
