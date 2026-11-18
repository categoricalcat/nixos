{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../../modules/options/host.nix
    ../../modules/options/server-mode.nix
    ../../modules/options/desktop.nix
    ../programs/fastfetch.nix
    ../programs/tui.nix
    ../programs/neovim.nix
  ];

  xdg.enable = true;

  home = {
    # xterm-kitty terminfo follows the user to hosts without kitty, since
    # TERM is no longer clobbered to xterm-256color.
    packages = [ pkgs.kitty.terminfo ];

    sessionVariables = lib.mkMerge [
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        TERMINFO = "/run/current-system/sw/share/terminfo";
        TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:/run/current-system/sw/share/terminfo";
      })
      {
        EDITOR = lib.mkDefault "nvim";
        VISUAL = lib.mkDefault "nvim";
        NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
      }
    ];

    sessionPath = [
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.npm-global/bin"
    ];
  };

  programs = {
    home-manager.enable = true;

    zsh = {
      enable = true;
      package = pkgs.zsh;
      enableCompletion = true;
      defaultKeymap = "emacs";
      syntaxHighlighting.enable = true;

      autosuggestion = {
        enable = true;
        highlight = "fg=#${(import ../../modules/theme.nix).base03}";
        strategy = [
          "history"
          "completion"
        ];
      };

      history = {
        # HM's default path sits in ZDOTDIR (~/.config/zsh); pin the
        # pre-migration location so history continuity is preserved.
        path = "${config.home.homeDirectory}/.zsh_history";
        size = 10000;
        save = 10000;
        ignoreDups = true;
        share = true;
      };

      setOptions = [
        "AUTO_CD"
        "AUTO_PUSHD"
        "PUSHD_IGNORE_DUPS"
      ];

      localVariables.ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE = "20";

      shellGlobalAliases = {
        "..." = "../..";
        "...." = "../../..";
        "....." = "../../../..";
      };

      shellAliases = lib.mkMerge [
        {
          ".." = "cd ..";
          grep = "grep --color=auto";
          zshrc = "source $ZDOTDIR/.zshrc";
          query = "~/the.files/query.sh";
          nix-dr = "nh os build .";
          gen-commit = "~/the.files/git-commit-msg.sh";
          usb-ssh = "~/the.files/usb-ssh.sh";
          zyi = "mosh yifuwuqi -- zellij attach -c main";
          pps = "podman ps";
          ppsa = "podman ps -a";
          pimg = "podman images";
          pex = "podman exec -it";
          plog = "podman logs";
          pstop = "podman stop";
          prm = "podman rm";
          prmi = "podman rmi";
          prun = "podman run";
          pbuild = "podman build";
          ppull = "podman pull";
          ppush = "podman push";
          ptop = "podman top";
          pstats = "podman stats";
          pinspect = "podman inspect";
          pc = "podman-compose";
          pcu = "podman-compose up";
          pcud = "podman-compose up -d";
          pcd = "podman-compose down";
          pcl = "podman-compose logs";
          pclf = "podman-compose logs -f";
          pcps = "podman-compose ps";
          pcr = "podman-compose restart";
          pprune = "podman system prune";
          pinfo = "podman info";
          pversion = "podman version";
        }
        (lib.mkIf config.programs.yazi.enable { yy = "y"; })
      ];

      # Autoloaded from $fpath; bodies here, no function wrappers needed.
      siteFunctions = {
        jira = ''
          local company="$1"
          local ticket="$2"
          local url="https://''${company}.atlassian.net/browse/''${ticket}"
          echo "$url"
        '';
        gh-pr = ''
          gh pr create -a @me --fill-verbose -B "$1"
        '';
      };

      initContent = builtins.readFile ../assets/dotfiles/zshrc;
    };
  };
}
