{
  pkgs,
  lib,
  config,
  ...
}:

{
  _module.args =
    let
      allAddresses = import ./addresses.nix;
    in
    {
      inherit allAddresses;
      addresses = allAddresses.hosts.${config.networking.hostName};
      systemdHardening = (import ./hardening.nix).baseline;
    };

  imports = [
    ./nix-ld.nix
    ./host.nix
    ./maintenance.nix
    ./server-mode.nix
    ./services/ai/opencode.nix
    ./services/chrony.nix
    ./services/kmscon.nix
    ../docs/service.nix
  ];

  nix.package = lib.mkForce pkgs.lixPackageSets.lix_2_96.lix;
  nixpkgs.config = {
    allowUnfree = true;
    # gtk2 is marked broken ahead of its NixOS 27.05 removal, but Home Manager's
    # input-method gtk2 cache, lutris, onlyoffice and ir-lv2 still depend on it.
    problems.handlers."gtk+".broken = "warn";
  };
  nixpkgs.overlays = import ../nix/overlays.nix;
  environment.defaultPackages = lib.mkForce [ ];

  systemd.tmpfiles.rules = [
    "d /tmp/ai 1777 root root 1d -"
  ];

  services.resolved = {
    enable = lib.mkDefault true;
    settings.Resolve = {
      DNSStubListener = lib.mkDefault "no";
      DNSSEC = lib.mkDefault "no";
      Cache = lib.mkDefault "no";
    };
  };

  security.sudo.enable = false;
}
