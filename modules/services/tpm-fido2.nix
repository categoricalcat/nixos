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
    # Ensure TPM is enabled for the host
    security.tpm2.enable = true;

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
      wantedBy = [ "default.target" ];
      # The daemon requires access to /dev/tpmrm0 and /dev/uhid
      serviceConfig = {
        ExecStart = "${tpm-fido2-pkg}/bin/tpm-fido2";
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
}
