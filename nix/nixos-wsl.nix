# WSL NixOS configuration
{
  nixpkgs,
  sops-nix,
  nixowos,
  nixos-wsl,
  home-manager,
  ...
}:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    sops-nix.nixosModules.sops
    nixowos.nixosModules.default
    nixos-wsl.nixosModules.default
    home-manager.nixosModules.home-manager
    ../modules/wsl.nix
    ../secrets/sops.nix
    ../modules/packages.nix
    ../modules/server-mode.nix
    ../modules/server-settings.nix
    ../modules/locale.nix
    ../users/users.nix
    {
      nixowos.enable = true;

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.fufud = import ../users/home-fufud.nix;
      };
    }
  ];
}
