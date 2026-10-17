{ lib, ... }:
{
  imports = [
    ./yijia.nix
  ];

  # Priority 101 beats yijia's mkDefault "yi" and loses to the NixOS
  # home-manager module, which sets these from users.users.root.
  home = {
    username = lib.mkOverride 101 "root";
    homeDirectory = lib.mkOverride 101 "/root";
  };
}
