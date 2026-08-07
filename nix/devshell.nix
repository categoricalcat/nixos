_: {
  perSystem =
    {
      pkgs,
      inputs',
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

      code-cursor-nix = builtins.getFlake "https://github.com/jacopone/code-cursor-nix/archive/refs/heads/main.tar.gz";
      antigravity-nix = builtins.getFlake "https://github.com/jacopone/antigravity-nix/archive/refs/heads/master.tar.gz";

      nixosRebuildWrapper = pkgs.writeShellScriptBin "nixos-rebuild" ''
        exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@"
      '';

      inspectWrapper = pkgs.writeShellScriptBin "inspect" (builtins.readFile ./inspect.sh);

      diffToCommitWrapper = pkgs.writeShellScriptBin "diff-to-commit" ''
        diff=$(git diff --cached)
        if [ -z "$diff" ]; then
          echo "No staged changes found."
          exit 1
        fi

        echo "Generating commit message..."
        msg_file="$(git rev-parse --git-dir)/COMMIT_EDITMSG"

        agy -p "Write a concise git commit message for this staged diff. Output ONLY the commit message itself (no markdown blocks or preamble). DIFF: $diff" > "$msg_file"
        exec git commit -e -F "$msg_file"
      '';

      nxdAgyWrapper = pkgs.writeShellScriptBin "nxd-agy" ''
        exec ${antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli}/bin/agy "$@"
      '';

      nxdAgentWrapper = pkgs.writeShellScriptBin "nxd-agent" ''
        exec ${antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli}/bin/agy "$@"
      '';

      nxdCursorWrapper = pkgs.writeShellScriptBin "nxd-cursor" ''
        exec ${code-cursor-nix.packages.${pkgs.stdenv.hostPlatform.system}.cursor}/bin/cursor "$@"
      '';

      nxdAntigravityWrapper = pkgs.writeShellScriptBin "nxd-antigravity" ''
        exec ${antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-ide}/bin/google-antigravity-ide "$@"
      '';

      nixDevPkgs = with pkgs; [
        statix # Lints and suggestions for Nix
        deadnix # Nix dead code locator
        nixpkgs-hammering # Linter for Nixpkgs packages
        nil # Nix language server
        nixd # Nix language server (with statix/deadnix support)
        nixfmt # Official RFC-166 Nix formatter
        direnv # Environment switcher for shell
        nix-update # Swiss-knife for updating nix packages
        nix-init # Generator for Nix packages from URLs
        comma # Run software without installing it (, <pkg>)
      ];

      defaultShell = pkgs.mkShell {
        packages =
          rustPkgs
          ++ nixDevPkgs
          ++ [
            pkgs.zsh
            nixosRebuildWrapper
            inspectWrapper
            diffToCommitWrapper
            nxdAgyWrapper
            nxdAgentWrapper
            nxdCursorWrapper
            nxdAntigravityWrapper
            antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-ide
            antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
            code-cursor-nix.packages.${pkgs.stdenv.hostPlatform.system}.cursor
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

      packages.default = defaultShell;
      packages.sandbox = sandboxShell;
    };
}
