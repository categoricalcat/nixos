# /etc/nixos/flake.nix
{
  description = "福福的flake~";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-wsl,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        wsl = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            {
              system.stateVersion = "25.11";
              wsl.defaultUser = "fufu-wsl";
              wsl.enable = true;

              nixpkgs.config = {
                allowUnfree = true; 
                cudaSupport = false; 
                rocmSupport = true; 
              };
            }
            ./modules/packages.nix
            ./modules/locale.nix
          ];
        };

        fufuwuqi = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            ./configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.fufud = import ./users/home-fufud.nix;
              home-manager.users.workd = import ./users/home-workd.nix;
            }
          ];
        };
      };
    };
}
