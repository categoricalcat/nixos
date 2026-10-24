{ ... }:

{
  imports = [ ../../modules/boot-common.nix ];

  boot.loader.systemd-boot.configurationLimit = 10;
}
