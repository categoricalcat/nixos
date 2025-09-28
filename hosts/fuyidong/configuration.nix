{
  ...
}:

{
  imports = [
    ./boot.nix
    ./hardware.nix
    ../../secrets/sops.nix
    ../../modules/packages.nix
    ../../modules/locale.nix
    ../../modules/fonts.nix
    ../../modules/desktop.nix
    ../../users/users.nix
  ];

  system.stateVersion = "25.11";

  programs.nix-ld.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config = {
    allowUnfree = true;
  };

  nixowos.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.fufud = import ../../users/home-fufud.nix;
  };
}
