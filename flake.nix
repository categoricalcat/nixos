{
  description = "福福的flake~";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixowos = {
      url = "github:categoricalcat/nixowos";
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

    quickshell = {
      # add ?ref=<tag> to track a tag
      url = "git+https://git.outfoxxed.me/quickshell/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dgop = {
      url = "github:AvengeMedia/dgop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.follows = "quickshell";
    };

    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      home-manager,
      vscode-server,
      nixowos,
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
                vscode-server.nixosModules.default
                nixowos.nixosModules.default
                sops-nix.nixosModules.sops
                stylix.nixosModules.stylix
              ];
            in
            {
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
        };

        systems = [
          "x86_64-linux"
        ];
      }
    );
}
