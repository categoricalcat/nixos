# WSL-specific configuration module

{
  inputs,
  global,
  ...
}:

let
  mkHome = import ../../modules/home-manager.nix;
in
{
  imports = [
    ../../modules/services/samba/client.nix
    ../../secrets/sops.nix
    ../../modules/common.nix
    ../../modules/nix-settings.nix
    ../../modules/packages
    ../../modules/locale.nix
    ../../modules/fonts.nix
    # ../modules/desktop.nix
    ../../users/users.nix
  ];

  system.stateVersion = global.version;
  wsl.defaultUser = "yi";
  wsl.enable = true;
  services.resolved.enable = false;

  services.openssh = {
    enable = true;
    listenAddresses = [ ];
  };

  nixpkgs.config = {
    cudaSupport = false;
    rocmSupport = true;
  };

  home-manager = mkHome {
    inherit inputs;
    stateVersion = global.homeVersion;
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
