{
  description = "福福的flake~";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    systems.url = "github:nix-systems/default";
    git-hooks.url = "github:cachix/git-hooks.nix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixowos = {
      url = "github:yunfachi/nixowos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms-cli = {
      url = "github:AvengeMedia/danklinux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dankMaterialShell = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.dgop.follows = "dgop";
      inputs.dms-cli.follows = "dms-cli";
    };
  };

  outputs =
    {
      nixpkgs,
      systems,
      home-manager,
      nixowos,
      treefmt-nix,
      git-hooks,
      sops-nix,
      vscode-server,
      stylix,
      nixos-wsl,
      self,
      ...
    }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
      baseModules = [
        home-manager.nixosModules.home-manager
        vscode-server.nixosModules.default
        nixowos.nixosModules.default
        sops-nix.nixosModules.sops
        stylix.nixosModules.stylix
      ];
    in
    {
      nixosConfigurations = {
        fuchuang = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = baseModules ++ [
            nixos-wsl.nixosModules.default
            ./hosts/fuchuang/configuration.nix
          ];
        };

        fufuwuqi = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = baseModules ++ [
            ./hosts/fufuwuqi/configuration.nix
          ];
        };

        fuyidong = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = baseModules ++ [
            ./hosts/fuyidong/configuration.nix
          ];
        };
      };

      formatter = forEachSystem (
        system:
        import ./nix/formatter.nix {
          inherit system nixpkgs treefmt-nix;
        }
      );

      devShells = forEachSystem (system: {
        default = import ./nix/devshell.nix {
          inherit system nixpkgs;

          pre-commit-check = import ./nix/git-hooks.nix {
            inherit system nixpkgs git-hooks;
          };
        };
      });

      packages = forEachSystem (system: {
        inherit (self.devShells.${system}) default;
      });
    };
}
