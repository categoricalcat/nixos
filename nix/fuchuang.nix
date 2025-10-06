# WSL NixOS configuration
{
  nixpkgs,
  sops-nix,
  nixowos,
  nixos-wsl,
  home-manager,
  stylix,
  vscode-server,
  ...
}:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    sops-nix.nixosModules.sops
    nixowos.nixosModules.default
    nixos-wsl.nixosModules.default
    stylix.nixosModules.stylix
    home-manager.nixosModules.home-manager
    vscode-server.nixosModules.default
    ../hosts/fuchuang/configuration.nix
  ];
}
