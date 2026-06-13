let pkgs = import <nixpkgs> {};
in
pkgs.catppuccin-papirus-folders.override {
  accent = "pink";
  flavor = "mocha";
}
