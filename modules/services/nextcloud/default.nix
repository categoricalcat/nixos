{
  config,
  lib,
  pkgs,
  allAddresses,
  ...
}:

let
  inherit (config.services.nextcloud) datadir;
  occ = lib.getExe config.services.nextcloud.occ;
  jq = lib.getExe pkgs.jq;
  trustedDomainsCmd = lib.concatStringsSep "\n" (
    lib.imap0
      (i: v: ''
        ${occ} config:system:set trusted_domains \
          ${toString i} --value="${toString v}"
      '')
      (
        lib.unique (
          [ config.services.nextcloud.hostName ] ++ config.services.nextcloud.settings.trusted_domains
        )
      )
  );
in
{
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = "${config.networking.hostName}.yun";
    home = "/srv/nextcloud";

    database.createLocally = true;
    configureRedis = true;

    maxUploadSize = "10G";

    config = {
      dbtype = "mysql";
      adminuser = "admin";
      adminpassFile = config.sops.secrets."passwords/nextcloud".path;
    };

    settings = {
      trusted_domains = [
        "${allAddresses.hosts.yifuwuqi.network.lan.ipv4.host}"
      ];
    };
  };

  systemd.services.nextcloud-setup = {
    after = [ "sops-install-secrets.service" ];
    wants = [ "sops-install-secrets.service" ];
    script = lib.mkForce ''
      export OCC_BIN="${occ}"

      if [ -z "$(<"$CREDENTIALS_DIRECTORY/adminpass")" ]; then
        echo "adminpassFile ${config.services.nextcloud.config.adminpassFile} is empty!"
        exit 1
      fi

      # Check if systemd-tmpfiles setup worked correctly
      if [[ ! -O "${datadir}/config" ]]; then
        echo "${datadir}/config is not owned by user 'nextcloud'!"
        echo "Please check the logs via 'journalctl -u systemd-tmpfiles-setup'"
        echo "and make sure there are no unsafe path transitions."
        echo "(https://nixos.org/manual/nixos/stable/#module-services-nextcloud-pitfalls-during-upgrade)"
        exit 1
      fi

      if [ -d "${config.services.nextcloud.home}/nix-apps" ]; then
        echo "Cleaning up nix-apps; these are now bundled in the webroot store-path!"
        rm -r "${config.services.nextcloud.home}/nix-apps"
      fi
      if [ -d "${config.services.nextcloud.home}/apps" ]; then
        echo "Cleaning up apps; these are now bundled in the webroot store-path!"
        rm -r "${config.services.nextcloud.home}/apps"
      fi

      if [[ ! -s ${datadir}/config/config.php ]]; then
        DBPASS=""
        export DBPASS

        ADMINPASS="$(<"$CREDENTIALS_DIRECTORY/adminpass")"
        export ADMINPASS

        ${occ} maintenance:install \
          --admin-pass "$ADMINPASS" \
          --admin-user "${config.services.nextcloud.config.adminuser}" \
          --data-dir "${datadir}/data" \
          --database "${config.services.nextcloud.config.dbtype}" \
          --database-host "${config.services.nextcloud.config.dbhost}" \
          --database-name "${config.services.nextcloud.config.dbname}" \
          --database-pass "$DBPASS" \
          --database-user "${config.services.nextcloud.config.dbuser}"

        status_output="$($OCC_BIN status --output=json 2>&1 || true)"
        status_json="$(printf '%s\n' "$status_output" | sed -n '/^{/,$p')"
        if ! printf '%s\n' "$status_json" | ${jq} -e '.installed == true' >/dev/null 2>&1; then
          echo "Nextcloud install did not complete successfully; refusing to run upgrade."
          if [ -n "$status_output" ]; then
            printf '%s\n' "$status_output"
          fi
          exit 1
        fi
      fi

      $OCC_BIN upgrade

      $OCC_BIN config:system:delete trusted_domains

      ${lib.optionalString
        (config.services.nextcloud.extraAppsEnable && config.services.nextcloud.extraApps != { })
        ''
          $OCC_BIN app:enable ${lib.concatStringsSep " " (lib.attrNames config.services.nextcloud.extraApps)}
        ''
      }

      ${trustedDomainsCmd}
    '';
  };

  sops.secrets."passwords/nextcloud" = {
    owner = "nextcloud";
    group = "nextcloud";
  };

  # Ensure the nextcloud user and group exist so sops-install-secrets doesn't fail
  users.groups.nextcloud = { };
  users.users.nextcloud = {
    isSystemUser = true;
    group = "nextcloud";
  };
}
