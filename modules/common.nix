{
  pkgs,
  lib,
  inputs,
  config,
  ...
}:

{
  _module.args = {
    allAddresses = import ./addresses.nix;
    systemdHardening = {
      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      ProtectProc = "invisible";
      RestrictAddressFamilies = lib.splitString " " "AF_UNIX AF_INET AF_INET6";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = lib.splitString " " "@system-service ~@privileged";
    };
  };

  imports = [
    ./nix-ld.nix
    ./host.nix
    ./maintenance.nix
    ./server-mode.nix
    ./services/ai/opencode.nix
    ./services/chrony.nix
    ./services/kmscon.nix
  ];

  home-manager.sharedModules = [
    {
      inherit (config) host serverMode;
    }
  ];

  nix.package = lib.mkForce pkgs.lixPackageSets.lix_2_96.lix;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = import ../nix/overlays.nix { inherit inputs; };
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
