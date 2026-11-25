# The human credential store. SOPS stays the machine-facing store; this is
# the one people read and write through Bitwarden clients.
#
# Pre-deploy: add tokens/vaultwarden-admin to sops (docs/src/services/secrets.md).
# Post-deploy: open https://vaultwarden.aset.love/admin with that token and
# invite the first account; signups stay closed.
{
  config,
  pkgs,
  allAddresses,
  systemdHardening,
  ...
}:

let
  inherit (allAddresses.hosts.yifuwuqi.services) vaultwarden postgresql;
  database = postgresql.databases.vaultwarden;
  backupSlot = config.yi.maintenance.slots.backups;
  dataDir = "/var/lib/${config.systemd.services.vaultwarden.serviceConfig.StateDirectory}";
  backupDir = "/var/backup/vaultwarden";
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "yifuwuqi";
      message = "modules/services/vaultwarden.nix: may only be imported on yifuwuqi (its database is yifuwuqi's registry postgres)";
    }
  ];

  sops.secrets."tokens/vaultwarden-admin" = { };
  sops.templates."vaultwarden.env" = {
    content = ''
      ADMIN_TOKEN=${config.sops.placeholder."tokens/vaultwarden-admin"}
    '';
    restartUnits = [ "vaultwarden.service" ];
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    environmentFile = config.sops.templates."vaultwarden.env".path;
    # Peer auth on the socket: the service account and the database role are
    # both `vaultwarden`, so the URL carries no password.
    config = {
      DATABASE_URL = "postgresql:///${database}?host=${postgresql.socketDir}";
      DOMAIN = "https://${vaultwarden.domain}";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = vaultwarden.port;
      SIGNUPS_ALLOWED = false;
    };
  };

  # With the Postgres backend the dump holds the vault rows, but attachments,
  # sends and the token-signing key stay in the data folder: a restore needs
  # both artefacts.
  services.postgresqlBackup = {
    enable = true;
    databases = [ database ];
    startAt = backupSlot.calendar;
  };

  systemd = {
    services.vaultwarden = {
      requires = [ "postgresql.target" ];
      wants = [ "sops-install-secrets.service" ];
      after = [
        "postgresql.target"
        "sops-install-secrets.service"
      ];
    };

    services.backup-vaultwarden-data = {
      description = "Archive the Vaultwarden data folder";
      path = [
        pkgs.gnutar
        pkgs.gzip
      ];
      script = ''
        tar --create --gzip --file ${backupDir}/data.tar.gz.in-progress \
          --directory ${dataDir} --exclude ./icon_cache --exclude ./tmp .
        mv ${backupDir}/data.tar.gz.in-progress ${backupDir}/data.tar.gz
      '';
      serviceConfig = systemdHardening // {
        Type = "oneshot";
        User = "vaultwarden";
        Group = "vaultwarden";
        UMask = "0077";
        ReadWritePaths = [ backupDir ];
      };
    };

    timers."postgresqlBackup-${database}" = { inherit (backupSlot) timerConfig; };
    timers.backup-vaultwarden-data = backupSlot.timer;

    tmpfiles.rules = [ "d ${backupDir} 0700 vaultwarden vaultwarden -" ];
  };
}
