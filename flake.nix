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
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixowos = {
      url = "github:yunfachi/nixowos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix.url = "github:numtide/treefmt-nix";

    systems.url = "github:nix-systems/default";
    git-hooks.url = "github:cachix/git-hooks.nix";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      systems,
      home-manager,
      nixos-wsl,
      nixowos,
      treefmt-nix,
      git-hooks,
      sops-nix,
      vscode-server,
      stylix,
      ...
    }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      nixosConfigurations =
        let
          fuchuangConfig = import ./nix/fuchuang.nix;
          fufuwuqiConfig = import ./nix/fufuwuqi.nix;
        in
        {
          fuchuang = fuchuangConfig {
            inherit
              nixpkgs
              sops-nix
              nixowos
              nixos-wsl
              home-manager
              vscode-server
              stylix
              inputs
              ;
          };

          fufuwuqi = fufuwuqiConfig {
            inherit
              nixpkgs
              sops-nix
              nixowos
              home-manager
              vscode-server
              stylix
              inputs
              ;
          };

          fuyidong = import ./nix/fuyidong.nix {
            inherit
              nixpkgs
              sops-nix
              nixowos
              home-manager
              vscode-server
              stylix
              inputs
              ;
          };

        };

      # nix fmt uses this (treefmt wrapper)
      formatter = forEachSystem (
        system:
        import ./nix/formatter.nix {
          inherit system nixpkgs treefmt-nix;
        }
      );

      # Development shell with pre-commit hooks
      devShells = forEachSystem (
        system:
        let
          pre-commit-check = import ./nix/git-hooks.nix {
            inherit system nixpkgs git-hooks;
          };
        in
        {
          default = import ./nix/devshell.nix {
            inherit system nixpkgs pre-commit-check;
          };
        }
      );
    };
}
