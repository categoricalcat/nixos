{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  cfg = config.hardware.fanatec;
  fanatecDir = "/home/yi/.config/fanatec";
  profileDir = "${fanatecDir}/profiles";
  seedDir = ../../../hosts/yitaishi/fanatec;
  hid-fanatecff =
    config.boot.kernelPackages.callPackage "${inputs.nixpkgs}/pkgs/os-specific/linux/hid-fanatecff"
      { };
in
{
  options.hardware.fanatec.enable = mkEnableOption "Fanatec CSL DD profiles";

  config = mkIf cfg.enable {

    boot.extraModulePackages = [ hid-fanatecff ];
    services.udev.packages = [ hid-fanatecff ];

    systemd.tmpfiles.rules = [
      "d ${fanatecDir} 0755 yi yi -"
      "d ${profileDir} 0755 yi yi -"
      "C ${fanatecDir}/current-profile 0644 yi yi - ${seedDir}/current-profile"
      "C ${profileDir}/ams2.env 0644 yi yi - ${seedDir}/ams2.env"
      "C ${profileDir}/beamng.env 0644 yi yi - ${seedDir}/beamng.env"
    ];

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="hid", ATTRS{idVendor}=="0eb7", ATTRS{idProduct}=="0020", TAG+="systemd", ENV{SYSTEMD_WANTS}="fanatec-tuning.service"
    '';

    systemd.services.fanatec-tuning = {
      description = "Apply Fanatec CSL DD tuning";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = getExe (
          pkgs.writeShellApplication {
            name = "fanatec-tuning";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              set -eu

              pointerFile="${fanatecDir}/current-profile"
              [ -r "$pointerFile" ] || exit 0

              profileFile="${profileDir}/$(tr -d '[:space:]' < "$pointerFile").env"
              [ -r "$profileFile" ] || exit 0

              sleep 2

              set -a
              # shellcheck source=/dev/null
              . "$profileFile"
              set +a

              for dev in \
                /sys/module/hid_fanatec/drivers/hid:fanatec/0003:0EB7:0020.*/ftec_tuning/* \
                /sys/module/hid_fanatec/drivers/hid:fanatec/0003:0EB7:0020.*/tuning_menu
              do
                [ -d "$dev" ] || continue

                for attr in SLOT SEN FF SHO BLI FFS DRI FOR SPR DPR NDP NFR FEI ACP INT NIN FUL; do
                  value="''${!attr-}"
                  [ -n "$value" ] || continue
                  [ -e "$dev/$attr" ] || continue
                  printf '%s' "$value" > "$dev/$attr"
                done
              done
            '';
          }
        );
      };
    };
  };
}
