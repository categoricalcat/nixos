{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.security.tpm-fido2;
  tpm-fido2-pkg = pkgs.callPackage ../../packages/tpm-fido2 { };
in
{
  options.security.tpm-fido2 = {
    enable = mkEnableOption "tpm-fido2 daemon for virtual FIDO2/U2F token via TPM and fprintd";
  };

  config = mkIf cfg.enable {
    # Ensure TPM is enabled and uhid is loaded for the virtual HID device
    security.tpm2.enable = true;
    boot.kernelModules = [ "uhid" ];

    # Make the package available on the system
    environment.systemPackages = [ tpm-fido2-pkg ];

    # Add udev rules to allow the user/group to access /dev/uhid
    # We will grant access to the plugdev group or allow the logged-in user
    services.udev.extraRules = ''
      KERNEL=="uhid", SUBSYSTEM=="misc", GROUP="plugdev", MODE="0660"
    '';

    # Create the plugdev group if it doesn't exist
    users.groups.plugdev = { };

    # Systemd user service
    systemd.user.services.tpm-fido2 = {
      description = "Virtual FIDO2 token protected by TPM and fprintd";
      wantedBy = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      # Only run for users granted access to /dev/tpmrm0 and /dev/uhid
      unitConfig.ConditionGroup = [
        "tss"
        "plugdev"
      ];
      # userpresence.go shells out to fprintd-verify and notify-send
      path = [
        pkgs.fprintd
        pkgs.libnotify
      ];
      serviceConfig = {
        # Guard against switch/boot races where /dev/uhid is still a 0600 static
        # node; --tray swallows device errors in a goroutine instead of exiting.
        ExecStartPre = "${lib.getExe' pkgs.coreutils "test"} -r /dev/uhid -a -w /dev/uhid";
        ExecStart = "${lib.getExe tpm-fido2-pkg} --mode=daemon --tray";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
