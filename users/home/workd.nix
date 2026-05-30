{
  pkgs,
  ...
}:

{
  imports = [ ./common.nix ];

  home.username = "workd";
  home.homeDirectory = "/home/workd";

  home.packages = with pkgs; [
    nodejs_24
  ];
}
