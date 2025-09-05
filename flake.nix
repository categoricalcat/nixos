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

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
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
      vscode-server,
      ...
    }@inputs:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

    in
    {
      nixosConfigurations =
        let
          wslConfig = import ./nix/wsl.nix;
          fuwuqiConfig = import ./nix/fuwuqi.nix;
        in
        {
          wsl = wslConfig {
            inherit
              nixpkgs
              sops-nix
              nixowos
              nixos-wsl
              home-manager
              vscode-server
              ;
          };

          fuwuqi = fuwuqiConfig {
            inherit
              nixpkgs
              sops-nix
              nixowos
              home-manager
              vscode-server
              inputs
              ;
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
        import ./nix/formatter.nix {
          inherit system nixpkgs treefmt-nix;
        }
      );

      # Development shell with pre-commit hooks
      devShells = forAllSystems (
        system:
        let
          pre-commit-check = import ./nix/pre-commit-hooks.nix {
            inherit system nixpkgs pre-commit-hooks;
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
