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
    nixowos = {
      url = "github:yunfachi/nixowos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-wsl,
      nixowos,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        wsl = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixowos.nixosModules.default
            nixos-wsl.nixosModules.default
            ./modules/wsl.nix
            ./modules/packages.nix
            ./modules/server-mode.nix
            ./modules/server-settings.nix
            ./modules/locale.nix
            ./users/users.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.fufud = import ./users/home-fufud.nix;
            }
            {
              nixowos.enable = true;
            }
          ];
        };

        fufuwuqi = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            nixowos.nixosModules.default
            home-manager.nixosModules.home-manager
            ./configuration.nix
            # {
            #   home-manager.useGlobalPkgs = true;
            #   home-manager.useUserPackages = true;
            #   home-manager.users.fufud = import ./users/home-fufud.nix;
            #   home-manager.users.workd = import ./users/home-workd.nix;
            # }
            {
              nixowos.enable = true;
            }
          ];
        };
      };

      # homeConfigurations = {
      #   standaloneHomeManagerConfig = home-manager.lib.homeManagerConfiguration {
      #     modules = [
      #       nixowos.homeModules.default
      #     ];
      #   };
      # };
    };
}
