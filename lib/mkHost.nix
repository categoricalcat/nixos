# mkHost: build a nixosSystem with shared modules and a host config
{
  nixpkgs,
  sops-nix,
  nixowos,
  home-manager,
  vscode-server,
}:
{
  system ? "x86_64-linux",
  hostConfigPath,
  extraModules ? [ ],
  specialArgs ? { },
}:

nixpkgs.lib.nixosSystem {
  inherit system;
  inherit specialArgs;
  modules = [
    sops-nix.nixosModules.sops
    nixowos.nixosModules.default
    home-manager.nixosModules.home-manager
    vscode-server.nixosModules.default
    hostConfigPath
  ]
  ++ extraModules;
}
