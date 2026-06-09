{ lib, pkgs, ... }:

let
  enforceNoPowerSaving = pkgs.writeShellScript "enforce-yitaishi-no-power-saving" ''
    set -euo pipefail
    shopt -s nullglob

    for policy in /sys/class/scsi_host/host*/link_power_management_policy; do
      echo max_performance > "$policy" || true
    done

    for preference in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
      echo performance > "$preference" || true
    done

    for boost in /sys/devices/system/cpu/cpufreq/boost /sys/devices/system/cpu/amd_pstate/cpb_boost; do
      if [ -w "$boost" ]; then
        echo 1 > "$boost" || true
      fi
    done

    for level in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
      echo high > "$level" || true
    done

  '';

  resumeTargets = [
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];
in
{
  services = {
    auto-cpufreq.enable = false;
    power-profiles-daemon.enable = false;
    tlp.enable = false;

    tuned = {
      enable = true;
      ppdSupport = true;
      ppdSettings = {
        main = {
          default = "performance";
          battery_detection = false;
        };
        profiles = {
          power-saver = "yitaishi-power-saver";
          balanced = "yitaishi-balanced";
          performance = "yitaishi-performance";
        };
        battery = { };
      };
      settings = {
        daemon = true;
        dynamic_tuning = false;
        recommend_command = false;
      };
      profiles = {
        yitaishi-performance = {
          main.include = "latency-performance";
          cpu = {
            governor = "performance";
            energy_perf_bias = "performance";
            min_perf_pct = 100;
          };
          # Keep the performance profile aligned with the zram-first VM policy.
          sysctl."vm.swappiness" = 100;
        };
        yitaishi-balanced.main.include = "yitaishi-performance";
        yitaishi-power-saver.main.include = "yitaishi-performance";
      };
    };

    logind.settings.Login = {
      IdleAction = "ignore";
      IdleActionSec = "0";
      HandleLidSwitch = "ignore";
      HandleLidSwitchDocked = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleSuspendKey = "ignore";
      HandleHibernateKey = "ignore";
    };
  };

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance";
    powertop.enable = false;
  };

  networking.networkmanager.wifi.powersave = false;

  systemd = {
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };

    services = {
      yitaishi-no-power-saving = {
        description = "Disable runtime power saving on yitaishi";
        wantedBy = [ "multi-user.target" ];
        after = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${enforceNoPowerSaving}";
        };
      };

      yitaishi-no-power-saving-resume = {
        description = "Reapply yitaishi no-power-saving policy after resume";
        wantedBy = resumeTargets;
        after = resumeTargets;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${enforceNoPowerSaving}";
        };
      };
    };
  };

  boot.kernelParams = lib.mkAfter [
    "pcie_aspm=off"
    "pcie_port_pm=off"
    "usbcore.autosuspend=-1"
    "nvme_core.default_ps_max_latency_us=0"
    "snd_hda_intel.power_save=0"
    "snd_hda_intel.power_save_controller=N"
    "amdgpu.runpm=0"
  ];
}
