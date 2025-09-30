{
  nixpkgs-stable,
  sops-nix,
  nixowos,
  home-manager,
  vscode-server,
  inputs,
  ...
}:

nixpkgs-stable.lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs; };
  modules = [
    sops-nix.nixosModules.sops
    nixowos.nixosModules.default
    home-manager.nixosModules.home-manager
    vscode-server.nixosModules.default
    ../hosts/fuyidong/configuration.nix
  ];
}
