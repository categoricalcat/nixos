# Main server (fufuwuqi) NixOS configuration
{
  nixpkgs,
  sops-nix,
  nixowos,
  home-manager,
  vscode-server,
  inputs,
  ...
}:

let
  hostConfigPath = ../hosts/fufuwuqi/configuration.nix;
  commonModule = {
    nixowos.enable = true;

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.fufud = import ../users/home-fufud.nix;
      users.workd = import ../users/home-workd.nix;
    };
  };
in
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs; };
  modules = [
    sops-nix.nixosModules.sops
    nixowos.nixosModules.default
    home-manager.nixosModules.home-manager
    vscode-server.nixosModules.default
    hostConfigPath
    commonModule
  ];
}
