# WSL NixOS configuration
{
  nixpkgs,
  sops-nix,
  nixowos,
  nixos-wsl,
  home-manager,
  vscode-server,
  ...
}:

nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    sops-nix.nixosModules.sops
    nixowos.nixosModules.default
    nixos-wsl.nixosModules.default
    home-manager.nixosModules.home-manager
    vscode-server.nixosModules.default
    ../secrets/sops.nix
    ../modules/packages.nix
    ../modules/server-mode.nix
    ../modules/server-settings.nix
    ../modules/locale.nix
    # ../modules/desktop.nix
    ../users/users.nix
    ../hosts/fuchuang/configuration.nix
  ];
}
