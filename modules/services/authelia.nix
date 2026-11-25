# Authelia: the one login for every gated vhost. yirukou asks its AuthRequest
# endpoint before proxying (mkAuthGate in modules/services/proxy-vhosts.nix).
#
# Pre-deploy: add services/authelia/{storage-encryption-key,users/yi} to sops
# (docs/src/services/secrets.md).
# Post-deploy: the first login asks for a TOTP device; the one-time code that
# confirms it lands in /var/lib/authelia/notification.txt (read it as root).
{
  config,
  allAddresses,
  ...
}:

let
  inherit (allAddresses.hosts.yifuwuqi.services) authelia postgresql;
  database = postgresql.databases.authelia;
  backupSlot = config.yi.maintenance.slots.backups;
  instance = config.services.authelia.instances.main;
in
{
  assertions = [
    {
      assertion = config.networking.hostName == "yifuwuqi";
      message = "modules/services/authelia.nix: may only be imported on yifuwuqi (its database is yifuwuqi's registry postgres)";
    }
  ];

  sops.secrets = {
    "services/authelia/storage-encryption-key" = { };
    "services/authelia/users/yi" = { };
  };

  # Users are declarative and read-only: passwords change in sops, never
  # through Authelia, so reset and change are disabled below.
  sops.templates."authelia-users.yml" = {
    owner = instance.user;
    restartUnits = [ "authelia.service" ];
    content = builtins.toJSON {
      users.yi = {
        displayname = "yi";
        inherit (allAddresses) email;
        password = config.sops.placeholder."services/authelia/users/yi";
      };
    };
  };

  services.authelia.instances.main = {
    enable = true;
    # The unsuffixed instance runs as `authelia`, the role the registry
    # database creates, so socket peer auth needs no password.
    name = "";
    secrets = {
      # The JWT secret signs only password-reset links, and reset is off;
      # `manual` lifts the module's demand for one.
      manual = true;
      storageEncryptionKeyFile = config.sops.secrets."services/authelia/storage-encryption-key".path;
    };
    settings = {
      server.address = "tcp://127.0.0.1:${toString authelia.port}/";
      log.level = "info";
      default_2fa_method = "totp";
      access_control.default_policy = "two_factor";
      authentication_backend = {
        file.path = config.sops.templates."authelia-users.yml".path;
        password_reset.disable = true;
        password_change.disable = true;
      };
      # One cookie for the whole base domain, so a login on any gated host
      # covers every other one.
      session.cookies = [
        {
          domain = allAddresses.baseDomain;
          authelia_url = "https://${authelia.domain}";
        }
      ];
      storage.postgres = {
        address = "unix://${postgresql.socketDir}/.s.PGSQL.${toString config.services.postgresql.settings.port}";
        inherit database;
        username = database;
      };
      notifier.filesystem.filename = "/var/lib/authelia/notification.txt";
    };
  };

  systemd.services.authelia = {
    requires = [ "postgresql.target" ];
    wants = [ "sops-install-secrets.service" ];
    after = [
      "postgresql.target"
      "sops-install-secrets.service"
    ];
  };

  # TOTP enrolments are the only state here that config cannot recreate.
  services.postgresqlBackup = {
    enable = true;
    databases = [ database ];
    startAt = backupSlot.calendar;
  };
  systemd.timers."postgresqlBackup-${database}" = { inherit (backupSlot) timerConfig; };
}
