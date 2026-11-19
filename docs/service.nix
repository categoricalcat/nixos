{
  pkgs,
  lib,
  config,
  addresses,
  ...
}:

let
  # Shared with the CI docs check (nix/checks.nix): the service builds from
  # the live bind mount, the check from the flake source — same script.
  buildDocs = lib.getExe (import ./builder.nix { inherit pkgs; });

  commonHardening = {
    User = "docs";
    Group = "docs";
    ProtectHome = true;
    ProtectSystem = "strict";
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectProc = "invisible";
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectControlGroups = true;
    RestrictNamespaces = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    ReadWritePaths = [ "/var/lib/gang-docs" ];
    SystemCallErrorNumber = "EPERM";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
      "~@resources"
    ];
  };
in
{
  options.docs.enable = lib.mkEnableOption "Gang Documentation HTTP Server";

  config = lib.mkIf config.docs.enable {
    users.users.docs = {
      isSystemUser = true;
      group = "docs";
    };
    users.groups.docs = { };

    fileSystems."/var/lib/gang-docs/src" = {
      device = "/home/yi/the.files/nixos/docs";
      fsType = "none";
      options = [
        "bind"
        "ro"
      ];
    };

    systemd = {
      tmpfiles.rules = [
        "d /var/lib/gang-docs 0755 docs docs -"
        "d /var/lib/gang-docs/src 0755 root root -"
        "d /var/lib/gang-docs/book 0755 docs docs -"
      ];

      services = {
        docs = {
          description = "Gang Documentation HTTP Server";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          unitConfig.RequiresMountsFor = [ "/var/lib/gang-docs/src" ];
          preStart = "${buildDocs} /var/lib/gang-docs/src /var/lib/gang-docs/book";
          serviceConfig = commonHardening // {
            ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd /var/lib/gang-docs/book --port ${toString addresses.services.docs.port} --addr 127.0.0.1 --no-listing --no-server-id --hide-dotfiles";
            CapabilityBoundingSet = "";
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
            ];
            Restart = "always";
          };
        };

        docs-watcher = {
          description = "Gang Documentation Real-Time Watcher";
          wantedBy = [ "multi-user.target" ];
          after = [ "docs.service" ];
          wants = [ "docs.service" ];
          unitConfig.RequiresMountsFor = [ "/var/lib/gang-docs/src" ];
          serviceConfig = commonHardening // {
            ExecStart = "${pkgs.watchexec}/bin/watchexec -n -w /var/lib/gang-docs/src --debounce 1500ms --restart -- ${buildDocs} /var/lib/gang-docs/src /var/lib/gang-docs/book";
            Restart = "always";
          };
        };
      };
    };
  };
}
