{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.theFilesSshfs;
in
{
  options.theFilesSshfs.enable = lib.mkEnableOption "Mount ~/the-files via sshfs from fufud.lan:/home/fufud/the.files";

  config = lib.mkIf cfg.enable {
    home.activation.ensureTheFilesMountpoint = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$HOME/the-files"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod 700 "$HOME/the-files" || true
    '';

    home.packages = [ pkgs.sshfs ];

    systemd.user.services."sshfs-the-files" = {
      Unit = {
        Description = "SSHFS mount ~/the-files from fufud.lan:/home/fufud/the.files";
        After = [
          "network-online.target"
          "default.target"
        ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = ''${pkgs.sshfs}/bin/sshfs -o idmap=user,allow_other,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,StrictHostKeyChecking=accept-new,port=24212 fufud.lan:/home/fufud/the.files %h/the-files'';
        ExecStop = ''${pkgs.fuse3}/bin/fusermount3 -u %h/the-files || ${pkgs.fuse}/bin/fusermount -u %h/the-files'';
        Restart = "on-failure";
        RemainAfterExit = true;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
