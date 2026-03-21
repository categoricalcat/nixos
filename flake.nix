{
  description = "伊的flake~";

  outputs =
    inputs@{
      stylix,
      nixpkgs,
      sops-nix,
      nixos-wsl,
      flake-parts,
      home-manager,
      nixpkgs-small,
      home-manager-small,
      ...
    }:
    # https://flake.parts/module-arguments.html
    flake-parts.lib.mkFlake { inherit inputs; } (
      {
        ...
      }:
      {
        imports = [
          inputs.treefmt-nix.flakeModule
          inputs.git-hooks.flakeModule
          ./nix/treefmt.nix
          ./nix/git-hooks.nix
          ./nix/devshell.nix
        ];

        flake = {
          nixosConfigurations = {
            yichuang = nixpkgs-small.lib.nixosSystem {
              specialArgs = { inherit inputs; };
              modules = [
                home-manager-small.nixosModules.home-manager
                sops-nix.nixosModules.sops
                nixos-wsl.nixosModules.default
                ./hosts/yichuang/configuration.nix
              ];
            };

            yifuwuqi = nixpkgs-small.lib.nixosSystem {
              specialArgs = { inherit inputs; };
              modules = [
                sops-nix.nixosModules.sops
                home-manager-small.nixosModules.home-manager
                ./hosts/yifuwuqi/configuration.nix
              ];
            };

            yixiaoqing = nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs; };
              modules = [
                home-manager.nixosModules.home-manager
                sops-nix.nixosModules.sops
                stylix.nixosModules.stylix
                (_: {
                  nixpkgs.overlays = [ (_final: prev: { dgop = inputs.dgop.packages.${prev.system}.default; }) ];
                })
                ./hosts/yixiaoqing/configuration.nix
              ];
            };

            yitaishi = nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs; };
              modules = [
                home-manager.nixosModules.home-manager
                sops-nix.nixosModules.sops
                stylix.nixosModules.stylix
                ./hosts/yitaishi/configuration.nix
              ];
            };
          };
        };

        systems = [
          "x86_64-linux"
        ];
      }

    );

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-small.url = "github:NixOS/nixpkgs/nixos-25.11-small";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-small = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs-small";
    };

    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-float-sticky = {
      url = "github:probeldev/niri-float-sticky";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    thefiles = {
      url = "git+https://github.com/categoricalcat/the.files.git?submodules=1";
      flake = false;
    };
  };
}
