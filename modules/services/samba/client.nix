{
  allAddresses,
  lib,
  ...
}:

let
  shares = [
    "share"
    "the.files"
  ];

  mountPoints = map (name: "/mnt/smb/${name}") shares;

  # Equivalent of `systemd-escape --path`: "/" becomes "-", "-" becomes \x2d.
  escapeUnitPath =
    path:
    lib.concatStrings (
      map (
        c:
        if c == "/" then
          "-"
        else if c == "-" then
          "\\x2d"
        else
          c
      ) (lib.stringToCharacters (lib.removePrefix "/" path))
    );

  automountUnitNames = map (mountPoint: "${escapeUnitPath mountPoint}.automount") mountPoints;

  mountUnitNames = map (mountPoint: "${escapeUnitPath mountPoint}.mount") mountPoints;

  serverIp = allAddresses.hosts.yifuwuqi.network.lan.ipv4.host;
  credentialsFile = "/etc/samba/credentials/yi";
  mountCommonOptions = [
    "credentials=${credentialsFile}"
    "vers=3.11"
    "uid=yi"
    "gid=yi"
    "file_mode=0664"
    "dir_mode=0775"
    "mfsymlinks"
    "x-systemd.after=sops-install-secrets.service"
    "x-systemd.requires=sops-install-secrets.service"
    "x-systemd.automount"
    "x-systemd.mount-timeout=10s"
    "noauto"
    "nofail"
    "_netdev"
  ];
in
{
  sops.secrets."samba/credentials/yi" = {
    mode = "0600";
    path = credentialsFile;
  };

  boot.supportedFilesystems = [ "cifs" ];

  fileSystems = lib.listToAttrs (
    map (name: {
      name = "/mnt/smb/${name}";
      value = {
        device = "//${serverIp}/${name}";
        fsType = "cifs";
        options = mountCommonOptions;
      };
    }) shares
  );

  systemd = {
    services."user@" = {
      after = mountUnitNames ++ automountUnitNames;
    };

    services.smb-mounts-recover = {
      description = "Recover failed SMB automount units";
      script = ''
        for unit in ${lib.concatStringsSep " " automountUnitNames}; do
          if systemctl is-failed "$unit" >/dev/null 2>&1; then
            mount_unit="''${unit%.automount}.mount"
            systemctl reset-failed "$unit" "$mount_unit"
            systemctl restart "$unit"
          fi
        done
      '';
      serviceConfig = {
        Type = "oneshot";
      };
    };

    timers.smb-mounts-recover = {
      description = "Periodically recover failed SMB automount units";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "30s";
      };
    };
  };
}
