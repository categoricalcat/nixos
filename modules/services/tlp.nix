_: {
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      CPU_MIN_PERF_ON_AC = 1;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 40;

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;

      CPU_SCALING_DRIVER_ON_AC = "intel_pstate";
      CPU_SCALING_DRIVER_ON_BAT = "intel_pstate";

      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      PCIE_ASPM_ON_AC = "performance";
      PCIE_ASPM_ON_BAT = "powersupersave";

      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";

      NMI_WATCHDOG = 0;

      # ThinkPad-specific settings for suspend/resume reliability
      RESTORE_DEVICE_STATE_ON_STARTUP = 0; # Prevent restore conflicts on resume
      DEVICES_TO_DISABLE_ON_STARTUP = ""; # Ensure clean resume

      USB_AUTOSUSPEND = 1;
      USB_BLACKLIST_BTUSB = 1;
      USB_BLACKLIST_PHONE = 1;

      RUNTIME_PM_BLACKLIST = "";

      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_ON_BAT = 1;
      SOUND_POWER_SAVE_CONTROLLER = "Y";

      SATA_LINKPWR_ON_BAT = "min_power";

      CPU_HWP_DYN_BOOST_ON_AC = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 0;

      WOL_DISABLE = "Y";
    };
  };
}
