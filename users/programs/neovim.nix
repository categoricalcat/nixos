{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [
    inputs.nixvim.homeModules.nixvim
  ];

  config = lib.mkIf config.serverMode.developer {
    programs.nixvim = {
      enable = true;
      enableMan = false;
      defaultEditor = true;
      nixpkgs.source = inputs.nixpkgs;
      package = pkgs.neovim-unwrapped;

      opts = {
        number = true;
        relativenumber = true;
        shiftwidth = 2;
      };

      extraPlugins = with pkgs.vimPlugins; [
        vim-rsi # Provides Readline / Emacs bindings
      ];

      extraPackages = with pkgs; [
        gcc
        tree-sitter
      ];

      plugins = {
        lualine.enable = true;
        telescope.enable = true;
        octo.enable = true;
        diffview.enable = true;
        treesitter = {
          enable = true;
          settings = {
            highlight.enable = true;
            ensure_installed = [
              "nix"
              "lua"
              "bash"
              "vim"
              "vimdoc"
              "javascript"
              "typescript"
              "rust"
              "haskell"
              "json"
              "markdown"
              "markdown_inline"
            ];
          };
        };
        web-devicons.enable = true;

        lsp = {
          enable = true;
          keymaps = {
            lspBuf = {
              "K" = "hover";
              "gd" = "definition";
              "gr" = "references";
            };
          };
          servers = {
            nixd.enable = true;
            ts_ls.enable = true;
            denols.enable = true;
            hls = {
              enable = true;
              installGhc = false;
              package = pkgs.haskell-language-server;
            };
            rust_analyzer = {
              enable = true;
              installCargo = false;
              installRustc = false;
            };
          };
        };
      };
    };
  };
}
