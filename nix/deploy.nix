{
  self,
  inputs,
  lib,
  ...
}:
let
  addresses = import ../modules/addresses.nix;

  # deploy-rs's rollback machinery (`nix-env --rollback`, re-run of
  # <profile>/deploy-rs-activate) needs its own profile pointing at the
  # activatable wrapper — the real system profile must instead hold the raw
  # toplevel, the path switch-to-configuration writes to /run/current-system,
  # so nh lists remote deploys like local switches. The machinery profile must
  # NOT match `system-*-link`: lanzaboote enumerates generations with that
  # literal glob and hard-fails on non-numeric names (lzbt "Failed to extract
  # version", 2026-11-17 deploy). nix-collect-garbage -d cleans both profiles.
  mkNode =
    name:
    let
      toplevel = self.nixosConfigurations.${name}.config.system.build.toplevel;
      # Register the deployed generation before switch-to-configuration
      # (matching nixos-rebuild): both systemd-boot-builder and lanzaboote
      # enumerate `/nix/var/nix/profiles/system-*-link` during activation to
      # write boot entries and select the default generation. Registering after
      # leaves the bootloader one generation behind on every deploy. dry/test
      # register nothing.
      registerSystem = "nix-env --profile /nix/var/nix/profiles/system --set ${toplevel}";
    in
    {
      hostname = addresses.hosts.${name}.network.tailscale.ipv4.host;
      sshOpts = [
        "-p"
        (toString addresses.hosts.${name}.ssh.listenPort)
      ];
      profiles.system = {
        user = "root";
        sshUser = "root";
        profilePath = "/nix/var/nix/profiles/deploy-rs";
        path =
          (
            inputs.deploy-rs.lib.x86_64-linux.activate.custom
            // {
              dryActivate = "$PROFILE/bin/switch-to-configuration dry-activate";
              boot = ''
                ${registerSystem}
                $PROFILE/bin/switch-to-configuration boot
              '';
              test = "$PROFILE/bin/switch-to-configuration test";
            }
          )
            toplevel
            ''
              # work around https://github.com/NixOS/nixpkgs/issues/73404
              cd /tmp

              ${registerSystem}
              $PROFILE/bin/switch-to-configuration switch
            '';
      };
    };
in
{
  flake.deploy = {
    magicRollback = true;
    autoRollback = true;
    confirmTimeout = 30;
    # Derived from the registry's per-host deploy flag; pinned by
    # deploy-registry in nix/checks.nix.
    nodes = lib.genAttrs (lib.attrNames (
      lib.filterAttrs (_: host: host.deploy) addresses.hosts
    )) mkNode;
  };
}
