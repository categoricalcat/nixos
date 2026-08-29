_: {
  perSystem =
    {
      pkgs,
      ...
    }:
    let
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
        exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@"
      '';

      inspectWrapper = pkgs.writeShellScriptBin "inspect" (builtins.readFile ./scripts/inspect.sh);
      hostTreeWrapper = pkgs.writeShellScriptBin "host-tree" (builtins.readFile ./scripts/host-tree.sh);
      hostSizeWrapper = pkgs.writeShellScriptBin "host-size" (builtins.readFile ./scripts/host-size.sh);
      hostDiffWrapper = pkgs.writeShellScriptBin "host-diff" (builtins.readFile ./scripts/host-diff.sh);
      hostDeadWrapper = pkgs.writeShellScriptBin "host-dead" (builtins.readFile ./scripts/host-dead.sh);
      dnsWarmWrapper = pkgs.writeShellScriptBin "dns-warm" (builtins.readFile ./scripts/dns-warm.sh);
      hostWhyWrapper = pkgs.writeShellScriptBin "host-why" (builtins.readFile ./scripts/host-why.sh);
      hostAuditWrapper = pkgs.writeShellScriptBin "host-audit" (
        builtins.readFile ./scripts/host-audit.sh
      );

      wrappers = import ../packages/wrappers.nix { inherit pkgs; };

      nixDevPkgs = with pkgs; [
        statix # Lints and suggestions for Nix
        deadnix # Nix dead code locator
        shellcheck # Shell linter
        shfmt # Shell formatter
        shellharden # Shell syntax hardener and auto-quoter
        treefmt # Universal multi-file formatter
        nixpkgs-hammering # Linter for Nixpkgs packages
        nil # Nix language server
        nixd # Nix language server (with statix/deadnix support)
        nixfmt # Official RFC-166 Nix formatter
        direnv # Environment switcher for shell
        nix-update # Swiss-knife for updating nix packages
        nix-init # Generator for Nix packages from URLs
        comma # Run software without installing it (, <pkg>)
        nvd # Package version diff tool for Nix store paths
        deploy-rs # Multi-profile NixOS deployment tool
        fzf # Command-line fuzzy finder
        jq # Command-line JSON processor
        dnsx # Fast and multi-purpose DNS toolkit
        curl # Transfer data with URLs
      ];

      defaultShell = pkgs.mkShell {
        packages =
          rustPkgs
          ++ nixDevPkgs
          ++ (builtins.attrValues wrappers)
          ++ [
            pkgs.zsh
            nixosRebuildWrapper
            inspectWrapper
            hostTreeWrapper
            hostSizeWrapper
            hostDiffWrapper
            hostDeadWrapper
            dnsWarmWrapper
            hostWhyWrapper
            hostAuditWrapper
          ];
        shellHook = ''
          export RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}"
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
            ${pkgs.zsh}/bin/zsh
        '';
      };
    in
    {
      devShells.default = defaultShell;
      devShells.sandbox = sandboxShell;

      packages = {
        default = defaultShell;
        sandbox = sandboxShell;
      }
      // wrappers;
    };
}
