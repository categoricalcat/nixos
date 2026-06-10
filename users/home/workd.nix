{
  pkgs,
  ...
}:

{
  imports = [ ./common.nix ];

  home = {
    username = "workd";
    homeDirectory = "/home/workd";

    packages = with pkgs; [
      nodejs_24
    ];
  };
}
