_: {
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      CPU_MIN_PERF_ON_AC = 50;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 33;

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

      INTEL_GPU_MIN_FREQ_ON_AC = 0;
      INTEL_GPU_MIN_FREQ_ON_BAT = 0;
      INTEL_GPU_MAX_FREQ_ON_AC = 0;
      INTEL_GPU_MAX_FREQ_ON_BAT = 0;
      INTEL_GPU_BOOST_FREQ_ON_AC = 0;
      INTEL_GPU_BOOST_FREQ_ON_BAT = 0;

      NMI_WATCHDOG = 0;

      # ThinkPad-specific settings for suspend/resume reliability
      RESTORE_DEVICE_STATE_ON_STARTUP = 0; # Prevent restore conflicts on resume
      DEVICES_TO_DISABLE_ON_STARTUP = ""; # Ensure clean resume

      # USB autosuspend settings to prevent resume issues
      USB_AUTOSUSPEND = 1;
      USB_BLACKLIST_BTUSB = 1; # Bluetooth often causes issues
      USB_BLACKLIST_PHONE = 1; # Phones can interfere with resume

      # Runtime PM blacklist for problematic devices
      RUNTIME_PM_BLACKLIST = ""; # Add device IDs if needed
    };
  };
}
