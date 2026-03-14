{
  description = "伊的flake~";

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      nixpkgs-stable-small,
      home-manager,
      home-manager-stable,
      sops-nix,
      stylix,
      nixos-wsl,
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
          nixosConfigurations =
            let
              baseModules = [
                home-manager.nixosModules.home-manager
                sops-nix.nixosModules.sops
              ];
            in
            {
              yichuang = nixpkgs.lib.nixosSystem {
                specialArgs = { inherit inputs; };
                modules = baseModules ++ [
                  nixos-wsl.nixosModules.default
                  ./hosts/yichuang/configuration.nix
                ];
              };

              yifuwuqi = nixpkgs-stable-small.lib.nixosSystem {
                specialArgs = { inherit inputs; };
                modules = [
                  sops-nix.nixosModules.sops
                  home-manager-stable.nixosModules.home-manager
                  ./hosts/yifuwuqi/configuration.nix
                ];
              };

              yixiaoqing = nixpkgs.lib.nixosSystem {
                specialArgs = { inherit inputs; };
                modules = baseModules ++ [
                  stylix.nixosModules.stylix
                  ./hosts/yixiaoqing/configuration.nix
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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable-small.url = "github:NixOS/nixpkgs/nixos-25.11-small";
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
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-stable = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs-stable-small";
    };

    stylix = {
      url = "github:danth/stylix";
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
