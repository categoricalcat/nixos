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
    let
      global = {
        version = "26.05";
        homeVersion = "26.05";
      };
    in
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
              specialArgs = { inherit inputs global; };
              modules = [
                home-manager-small.nixosModules.home-manager
                sops-nix.nixosModules.sops
                nixos-wsl.nixosModules.default
                ./hosts/yichuang/configuration.nix
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

            yixiaoqing = nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs global; };
              modules = [
                home-manager.nixosModules.home-manager
                sops-nix.nixosModules.sops
                stylix.nixosModules.stylix
                (_: {
                  nixpkgs.overlays = [
                    (_final: prev: { dgop = inputs.dgop.packages.${prev.stdenv.hostPlatform.system}.default; })
                  ];
                })
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

            yirukou = nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs global; };
              modules = [
                home-manager.nixosModules.home-manager
                sops-nix.nixosModules.sops
                ./hosts/yirukou/configuration.nix
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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-small.url = "github:NixOS/nixpkgs/nixos-26.05-small";
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
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-small = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-small";
    };

    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    musnix = {
      url = "github:musnix/musnix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    niri-float-sticky = {
      url = "github:probeldev/niri-float-sticky";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    thefiles = {
      url = "github:categoricalcat/the.files";
    };

    attic.url = "github:zhaofengli/attic";
  };
}
