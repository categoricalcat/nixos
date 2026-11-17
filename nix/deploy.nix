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
      cfg = self.nixosConfigurations.${name};
      toplevel = cfg.config.system.build.toplevel;
      # Register the deployed generation so nh/nixos-rebuild agree with
      # /run/current-system. switch: after activation (matching what is now
      # running). boot: entry staged but not activated, mirroring
      # nixos-rebuild boot. dry/test register nothing.
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
                $PROFILE/bin/switch-to-configuration boot
                ${registerSystem}
              '';
              test = "$PROFILE/bin/switch-to-configuration test";
            }
          )
            toplevel
            ''
              # work around https://github.com/NixOS/nixpkgs/issues/73404
              cd /tmp

              $PROFILE/bin/switch-to-configuration switch

              ${registerSystem}

              # https://github.com/serokell/deploy-rs/issues/31
              ${lib.optionalString cfg.config.boot.loader.systemd-boot.enable "sed -i '/^default /d' ${cfg.config.boot.loader.efi.efiSysMountPoint}/loader/loader.conf"}
            '';
      };
    };
in
{
  flake.deploy = {
    magicRollback = true;
    autoRollback = true;
    confirmTimeout = 30;
    nodes = lib.genAttrs [
      "yifuwuqi"
      "yirukou"
      "yitaishi"
      "yixiaoqing"
    ] mkNode;
  };
}
