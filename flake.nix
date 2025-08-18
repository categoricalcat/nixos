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
    # Formatting and linting integration (minimal)
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nixos-wsl,
      nixowos,
      treefmt-nix,
      ...
    }@inputs:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
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
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.fufud = import ./users/home-fufud.nix;
              };
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
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.fufud = import ./users/home-fufud.nix;
                users.workd = import ./users/home-workd.nix;
              };
            }
            {
              nixowos.enable = true;
            }
          ];
        };
      };

      homeConfigurations = {
        standaloneHomeManagerConfig = home-manager.lib.homeManagerConfiguration {
          modules = [
            nixowos.homeModules.default
          ];
        };
      };

      # nix fmt uses this (treefmt wrapper)
      formatter = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          treefmtEval = treefmt-nix.lib.evalModule pkgs {
            projectRootFile = "flake.nix";
            programs = {
              nixfmt = {
                enable = true;
                package = pkgs.nixfmt-rfc-style;
              };
              statix.enable = true;
              deadnix.enable = true;
            };
          };
        in
        treefmtEval.config.build.wrapper
      );

      # No flake checks for treefmt; enforce via CI using `nix fmt -- --check`

      # Development shell with Nix language server
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nil
              statix
              deadnix
              nixfmt-rfc-style
            ];
          };
        }
      );
    };
}
