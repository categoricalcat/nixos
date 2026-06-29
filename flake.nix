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
      ...
    }:
    let
      global = {
        version = "26.05";
        homeVersion = "26.05";
      };
    in
    # https://flake.parts/module-arguments.html
    flake-parts.lib.mkFlake { inherit inputs; } (
      { self, ... }:
      {
        imports = [
          inputs.treefmt-nix.flakeModule
          inputs.git-hooks.flakeModule
          ./nix/treefmt.nix
          ./nix/git-hooks.nix
          ./nix/devshell.nix
        ];

        flake = {
          homeConfigurations.yijia = home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              system = "x86_64-linux";
              config.allowUnfree = true;
            };
            extraSpecialArgs = {
              inherit inputs;
              stateVersion = global.homeVersion;
              desktopEnvironment = "niri";
              desktopShell = "dms";
              monitors = [ ];
              keyboardProfile = "us-intl";
            };
            modules = [
              ./users/home/yi.nix
              { home.stateVersion = global.homeVersion; }
            ];
          };

          nixosConfigurations = {

            yixiaoqing = nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs global; };
              modules = [
                home-manager.nixosModules.home-manager
                sops-nix.nixosModules.sops
                stylix.nixosModules.stylix
                ./hosts/yixiaoqing/configuration.nix
              ];
            };

            yitaishi = nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs global; };
              modules = [
                home-manager.nixosModules.home-manager
                sops-nix.nixosModules.sops
                stylix.nixosModules.stylix
                inputs.lanzaboote.nixosModules.lanzaboote
                inputs.musnix.nixosModules.musnix
                ./hosts/yitaishi/configuration.nix
              ];
            };

            yifuwuqi = nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs global; };
              modules = [
                sops-nix.nixosModules.sops
                home-manager.nixosModules.home-manager
                ./hosts/yifuwuqi/configuration.nix
              ];
            };

            yirukou = nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs global; };
              modules = [
                home-manager.nixosModules.home-manager
                sops-nix.nixosModules.sops
                ./hosts/yirukou/configuration.nix
              ];
            };

            yichuang = nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs global; };
              modules = [
                home-manager.nixosModules.home-manager
                sops-nix.nixosModules.sops
                nixos-wsl.nixosModules.default
                ./hosts/yichuang/configuration.nix
              ];
            };

          };
        };

        perSystem = _: {
          checks.yijia = self.homeConfigurations.yijia.activationPackage;
        };

        systems = [
          "x86_64-linux"
        ];
      }

    );

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    flake-parts.url = "github:hercules-ci/flake-parts";
    attic.url = "github:zhaofengli/attic";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    musnix = {
      url = "github:musnix/musnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-float-sticky = {
      url = "github:probeldev/niri-float-sticky";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };
}
