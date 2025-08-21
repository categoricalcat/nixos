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
    treefmt-nix.url = "github:numtide/treefmt-nix";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nixos-wsl,
      nixowos,
      treefmt-nix,
      pre-commit-hooks,
      sops-nix,
      ...
    }@inputs:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Helper functions for modular configuration
      mkFormatter =
        {
          system,
          nixpkgs,
          treefmt-nix,
        }:
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
        treefmtEval.config.build.wrapper;

      mkPreCommitCheck =
        {
          system,
          nixpkgs,
          pre-commit-hooks,
        }:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            # Check formatting without modifying files
            nix-fmt-check = {
              enable = true;
              name = "nix fmt check";
              entry = "${pkgs.writeShellScript "nix-fmt-check" ''
                echo "Checking formatting..."
                nix fmt -- --ci
              ''}";
              files = "\\.nix$";
              pass_filenames = false;
            };

            # Run flake check
            flake-check = {
              enable = true;
              name = "nix flake check";
              entry = "${pkgs.writeShellScript "flake-check" ''
                echo "Running flake check..."
                nix flake check --no-build
              ''}";
              files = "\\.(nix|lock)$";
              pass_filenames = false;
            };
          };
        };

      mkDevShell =
        {
          system,
          nixpkgs,
          pre-commit-check,
        }:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.mkShell {
          inherit (pre-commit-check) shellHook;
        };
    in
    {
      nixosConfigurations = {
        wsl = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            sops-nix.nixosModules.sops
            nixowos.nixosModules.default
            nixos-wsl.nixosModules.default
            home-manager.nixosModules.home-manager
            ./modules/wsl.nix
            ./secrets/sops.nix
            ./modules/packages.nix
            ./modules/server-mode.nix
            ./modules/server-settings.nix
            ./modules/locale.nix
            ./users/users.nix
            {
              nixowos.enable = true;

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.fufud = import ./users/home-fufud.nix;
              };
            }
          ];
        };

        fufuwuqi = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            sops-nix.nixosModules.sops
            nixowos.nixosModules.default
            home-manager.nixosModules.home-manager
            ./configuration.nix
            {
              nixowos.enable = true;

              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.fufud = import ./users/home-fufud.nix;
                users.workd = import ./users/home-workd.nix;
              };
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
        mkFormatter {
          inherit system nixpkgs treefmt-nix;
        }
      );

      # Development shell with pre-commit hooks
      devShells = forAllSystems (
        system:
        let
          pre-commit-check = mkPreCommitCheck {
            inherit system nixpkgs pre-commit-hooks;
          };
        in
        {
          default = mkDevShell {
            inherit system nixpkgs pre-commit-check;
          };
        }
      );
    };
}
