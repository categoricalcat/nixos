{
  pkgs,
  lib,
  inputs,
  config,
  ...
}:

{
  _module.args.allAddresses = import ./addresses.nix;

  imports = [
    ./nix-ld.nix
    ./host.nix
    ./server-mode.nix
    ./services/ai/opencode.nix
    ./services/chrony.nix
    ./services/kmscon.nix
  ];

  home-manager.extraSpecialArgs = {
    headless = config.serverMode.headless;
    developer = config.serverMode.developer;
    tui = config.host.tui;
    desktopEnvironment = config.host.desktopEnvironment;
    desktopShell = config.host.desktopShell;
    vr = config.host.vr;
  };

  nix.package = lib.mkForce pkgs.lix;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = import ../nix/overlays.nix { inherit inputs; };
  environment.defaultPackages = lib.mkForce [ ];
}
