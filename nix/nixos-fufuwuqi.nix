# Main server (fufuwuqi) NixOS configuration
{
  nixpkgs,
  sops-nix,
  nixowos,
  home-manager,
  inputs,
  ...
}:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs; };
  modules = [
    sops-nix.nixosModules.sops
    nixowos.nixosModules.default
    home-manager.nixosModules.home-manager
    ../configuration.nix
    {
      nixowos.enable = true;

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.fufud = import ../users/home-fufud.nix;
        users.workd = import ../users/home-workd.nix;
      };
    }
  ];
}
