{ pkgs, inputs, ... }:
{
  imports = [
    inputs.nixvim.homeModules.nixvim
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    package = pkgs.neovim-unwrapped;

    opts = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
    };

    extraPlugins = with pkgs.vimPlugins; [
      vim-rsi # Provides Readline / Emacs bindings
    ];

    plugins = {
      lualine.enable = true;
      telescope.enable = true;
      treesitter.enable = true;
      web-devicons.enable = true;

      lsp = {
        enable = true;
        servers = {
          nixd.enable = true;
          ts_ls.enable = true;
          denols.enable = true;
          hls = {
            enable = true;
            installGhc = true;
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
}
