{ inputs, lib, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      system,
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

      # cursor-cli and antigravity-cli are unfree; keep allowUnfree scoped to
      # those two packages instead of the whole perSystem, so
      # treefmt/pre-commit/packages stay honest.
      unfreePkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate =
          p:
          builtins.elem (lib.getName p) [
            "cursor-cli"
            "antigravity-cli"
          ];
        overlays = [ ];
      };

      wrappers = import ../packages/wrappers.nix {
        inherit pkgs;
        antigravityCli = unfreePkgs.antigravity-cli;
      };

      # Dev/admin CLIs that used to live in modules/packages/dev.nix (system-wide
      # on every developer host). They belong to repo work, so they load only in
      # `nix develop` and never inflate an appliance system closure.
      devPkgs = [
        pkgs.bubblewrap
        pkgs.cloudflared
        unfreePkgs.cursor-cli
        pkgs.gcc
        pkgs.gh
        pkgs.gnumake
        unfreePkgs.k6
        pkgs.kubectl
        pkgs.python3
        pkgs.rclone
        pkgs.screen
        pkgs.systemd
      ];

      nixDevPkgs = (import ./cli-tools.nix { inherit pkgs; }) ++ [
        # Network and container admin CLIs: privileged or interactive,
        # needed only while working on the repo, on top of the shared
        # CLI suite.
        pkgs.brotli
        pkgs.ethtool
        pkgs.iftop
        pkgs.iperf3
        pkgs.nethogs
        pkgs.nftables
        pkgs.nmap
        pkgs.tcpdump
        pkgs.traceroute
        pkgs.buildah
        pkgs.dive
        pkgs.podman-compose
        pkgs.podman-tui
        pkgs.skopeo
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
        pkgs.git # Version control (needed for flakes/hooks on minimal hosts)
        pkgs.dnsx # Fast and multi-purpose DNS toolkit
        pkgs.curl # Transfer data with URLs
      ];

      # Single source of truth for shell, TUI, and git config across every
      # `nix develop` host/user (minimal servers without HM, root, bwrap sandbox).
      hmShell = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          inherit inputs;
          osConfig = { };
        };
        modules = [
          inputs.sops-nix.homeManagerModules.sops
          ../users/home/shell.nix
          ../users/programs/git.nix
          {
            home = {
              username = "devshell";
              homeDirectory = "/nonexistent-devshell-home";
              stateVersion = "26.05";
            };
            manual.manpages.enable = lib.mkForce false;
            xdg.mime.enable = lib.mkForce false;
            programs = {
              home-manager.enable = lib.mkForce false;
              zsh = {
                # Resolve $HOME dynamically because $ZDOTDIR and devshell-gitconfig are read-only in /nix/store.
                history.path = lib.mkForce "$HOME/.zsh_history";
                completionInit = ''
                  compdump="''${ZSH_COMPDUMP:-''${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-''${HOST:-host}}"
                  mkdir -p "''${compdump:h}"
                  autoload -U compinit && compinit -d "$compdump"
                  unset compdump
                '';
                initContent = lib.mkOrder 525 ''
                  fpath=("${devZshCompletions}/share/zsh/site-functions" "${devZshCompletions}/share/zsh/vendor-completions" $fpath)
                '';
              };
            };
          }
        ];
      };

      hmPackages = lib.filter (p: (lib.getName p) != "hm-session-vars.sh") hmShell.config.home.packages;

      devZshCompletions = pkgs.buildEnv {
        name = "devshell-zsh-completions";
        paths = hmPackages ++ nixDevPkgs ++ [ pkgs.git ];
        pathsToLink = [ "/share/zsh" ];
        ignoreCollisions = true;
      };

      devZdotdir = pkgs.writeTextDir ".zshrc" hmShell.config.programs.zsh.initContent;

      devCfgPrefix = "${hmShell.config.xdg.configHome}/";

      xdgConfigEntries = lib.concatMapAttrs (
        name: file:
        let
          rel = lib.removePrefix devCfgPrefix name;
        in
        if
          lib.hasPrefix devCfgPrefix name
          && !(lib.hasPrefix "systemd/" rel)
          && !(lib.hasPrefix "environment.d/" rel)
        then
          { ${rel} = file.source; }
        else
          { }
      ) hmShell.config.home.file;

      devXdgConfig = pkgs.linkFarm "devshell-xdg-config" (
        lib.mapAttrsToList (name: path: {
          inherit name path;
        }) xdgConfigEntries
      );

      devGitConfig = pkgs.writeText "devshell-gitconfig" (
        lib.replaceStrings [ "${hmShell.config.home.homeDirectory}/" ] [ "~/" ]
          hmShell.config.home.file.".gitconfig".text
      );

      hmVars = hmShell.config.home.sessionVariables;

      mkShellEnvHook = targetHome: ''
        export RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}"
        export ZDOTDIR="${devZdotdir}"
        export EDITOR="${hmVars.EDITOR}"
        export VISUAL="${hmVars.VISUAL}"
        export FZF_CTRL_R_COMMAND="${hmVars.FZF_CTRL_R_COMMAND}"
        export FZF_DEFAULT_COMMAND="${hmVars.FZF_DEFAULT_COMMAND}"
        export FZF_DEFAULT_OPTS="${hmVars.FZF_DEFAULT_OPTS}"
        export MCFLY_INTERFACE_VIEW="${hmVars.MCFLY_INTERFACE_VIEW}"
        export MCFLY_KEY_SCHEME="${hmVars.MCFLY_KEY_SCHEME}"
        export LOCALE_ARCHIVE_2_27="${hmVars.LOCALE_ARCHIVE_2_27}"
        export TERMINFO_DIRS="''${TERMINFO_DIRS:-/run/current-system/sw/share/terminfo}:${pkgs.kitty.terminfo}/share/terminfo"
        # The dev CA is trusted host-wide (packages/dev-certs/module.nix); repeat
        # it here so `next dev` inside the devshell verifies it even when the
        # caller's environment came from somewhere other than a login shell.
        if [ -e /persist/keys/dev/ca.pem ]; then
          export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
          export SSL_CERT_DIR=/etc/ssl/certs
          export NODE_EXTRA_CA_CERTS=/persist/keys/dev/ca.pem
        fi
        export XDG_CONFIG_DIRS="''${XDG_CONFIG_DIRS:+$XDG_CONFIG_DIRS:}${devXdgConfig}"
        : "''${STARSHIP_CONFIG:=${devXdgConfig}/starship.toml}"
        export STARSHIP_CONFIG
        _dev_home=${targetHome}
        _dev_xdg_cfg="$_dev_home/.config"
        if [ "$_dev_home" = "$HOME" ] && [ -n "''${XDG_CONFIG_HOME:-}" ]; then
          _dev_xdg_cfg="$XDG_CONFIG_HOME"
        fi
        [ -e "$_dev_home/.gitconfig" ] || [ -e "$_dev_xdg_cfg/git/config" ] || export GIT_CONFIG_GLOBAL="${devGitConfig}"
        [ -d "$_dev_xdg_cfg/direnv" ] || export DIRENV_CONFIG="''${DIRENV_CONFIG:-${devXdgConfig}/direnv}"
        [ -d "$_dev_xdg_cfg/zellij" ] || export ZELLIJ_CONFIG_DIR="''${ZELLIJ_CONFIG_DIR:-${devXdgConfig}/zellij}"
        unset _dev_home _dev_xdg_cfg
      '';

      repoScripts =
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

      # Fleet maintenance helpers: both drive `nix`/`nh`/`gh`/`statix` on the
      # repo, so they follow the rest of the dev tooling into the devshell.
      userScripts = [
        (pkgs.writeShellApplication {
          name = "nix-sanity";
          # No `pkgs.nix`: the devshell already put the host's Lix on PATH, and
          # pinning vanilla nix here would shadow it.
          runtimeInputs = [
            pkgs.coreutils
            pkgs.deadnix
            pkgs.git
            pkgs.nh
            pkgs.statix
            pkgs.util-linux
          ];
          text = builtins.readFile ../users/scripts/nix-sanity.sh;
        })
        (pkgs.writeShellApplication {
          name = "gh-backup";
          runtimeInputs = [
            pkgs.gh
            pkgs.git
          ];
          text = builtins.readFile ../users/scripts/gh-backup-repos.sh;
        })
      ];

      defaultShell = pkgs.mkShell {
        packages =
          rustPkgs
          ++ nixDevPkgs
          ++ hmPackages
          ++ (builtins.attrValues wrappers)
          ++ [
            nixosRebuildWrapper
            (pkgs.callPackage ../packages/dev-certs { })
          ]
          ++ devPkgs
          ++ userScripts
          ++ repoScripts;
        shellHook = ''
          # Keep `pkgs.neovim` off the front of PATH: prepending plain neovim
          # shadows Home Manager's nixvim wrapper, which then crashes loading
          # `~/.config/nvim/init.lua` without its plugin packpath. Only append
          # it as a fallback on minimal hosts (e.g. yirukou) without `nvim`.
          command -v nvim >/dev/null 2>&1 || export PATH="$PATH:${pkgs.neovim}/bin"
          ${config.pre-commit.installationScript}
          # `nix develop` can start in any subdir (or outside the repo via an
          # explicit flake ref); anchor at the flake root, not cwd.
          hook_root=$PWD
          while [ "$hook_root" != / ] && [ ! -e "$hook_root/flake.nix" ]; do
            hook_root=$(dirname "$hook_root")
          done
          if [ -d "$hook_root/packages/firecrawl-mcp" ] && { [ ! -e "$hook_root/packages/firecrawl-mcp/node_modules" ] || [ -L "$hook_root/packages/firecrawl-mcp/node_modules" ]; }; then
            ln -sfn ${config.packages.firecrawl-mcp.nodeModules}/node_modules "$hook_root/packages/firecrawl-mcp/node_modules"
          fi
          if [ -z "''${DIRENV_IN_ENVRC:-}" ]; then
            ${mkShellEnvHook ''"$HOME"''}
            export TMUX_TMPDIR="''${TMUX_TMPDIR:-''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}}"
            case "$-" in
              *i*) exec zsh ;;
            esac
          else
            export RUST_SRC_PATH="${pkgs.rustPlatform.rustLibSrc}"
          fi
        '';
      };

      sandboxShell = pkgs.mkShell {
        packages =
          rustPkgs
          ++ hmPackages
          ++ [
            pkgs.bubblewrap
            pkgs.unzip
            pkgs.git
            pkgs.neovim
          ];
        shellHook = ''
          echo "Entering ephemeral sandbox as 'none'..."
          ${mkShellEnvHook ''"/home/none"''}
          export TMUX_TMPDIR=/tmp

          exec bwrap \
            --unshare-user --uid 65534 --gid 65534 \
            --unshare-pid \
            --die-with-parent \
            `# Filesystem` \
            --ro-bind /nix/store /nix/store \
            --ro-bind /etc/resolv.conf /etc/resolv.conf \
            --ro-bind /etc/ssl /etc/ssl \
            --ro-bind /etc/static /etc/static \
            --tmpfs /home/none \
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
