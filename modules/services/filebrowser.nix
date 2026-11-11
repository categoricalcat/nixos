{
  allAddresses,
  config,
  lib,
  ...
}:

let
  files = allAddresses.hosts.${config.networking.hostName}.services.files;
  database = "/var/lib/filebrowser/database.db";
  root = "/home/yi";
  fb = lib.getExe config.services.filebrowser.package;
in
{
  sops.secrets."passwords/filebrowser" = {
    owner = "yi";
    mode = "0400";
  };

  services.filebrowser = {
    enable = true;
    user = "yi";
    group = "yi";
    settings = {
      address = "127.0.0.1";
      inherit (files) port;
      inherit database root;
    };
  };

  # The nixpkgs unit starts the server. This preStart owns the bolt db so the
  # server's quick setup cannot create an admin user and print a random
  # password. An existing yi user is left alone, including a password changed
  # in the UI.
  systemd.services.filebrowser = {
    after = [ "sops-install-secrets.service" ];
    wants = [ "sops-install-secrets.service" ];
    preStart = ''
      set -euo pipefail
      if [[ ! -e ${database} ]]; then
        ${fb} --database ${database} config init \
          --root ${root} \
          --address 127.0.0.1 \
          --port ${toString files.port} \
          --disableExec
      fi
      if ! ${fb} --database ${database} users ls | grep -qw yi; then
        password=$(tr -d '\r\n' < ${config.sops.secrets."passwords/filebrowser".path})
        if [[ -z $password ]]; then
          echo "passwords/filebrowser is empty" >&2
          exit 1
        fi
        ${fb} --database ${database} users add yi "$password" \
          --perm.admin=false \
          --perm.execute=false \
          --perm.create=false \
          --perm.rename=false \
          --perm.modify=false \
          --perm.delete=false \
          --perm.share=false \
          --perm.download=true
      fi
      rules=$(${fb} --database ${database} rules ls -u yi)
      if ! grep -F '/the.files/nixos/secrets' <<<"$rules" >/dev/null; then
        ${fb} --database ${database} rules add -u yi /the.files/nixos/secrets
      fi
    '';
    serviceConfig = {
      ProtectSystem = "strict";
      ProtectHome = "tmpfs";
      BindReadOnlyPaths = [ root ];
      ProtectProc = "invisible";
    };
  };
}
