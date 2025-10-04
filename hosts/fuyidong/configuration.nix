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
    ../../modules/services/battery.nix
    ../../users/users.nix
  ];

  system.stateVersion = "25.11";

  programs.nix-ld.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    download-buffer-size = 1073741824;
  };

  nixowos.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.fufud = import ../../users/home-fufud.nix;
  };
}
