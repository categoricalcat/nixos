{ pkgs, lib, ... }:

{

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 15;
      };
      efi.canTouchEfiVariables = true;
    };

    kernelModules = lib.mkAfter [
      "fuse"
      "kvm-intel"
      "coretemp"
    ];

    kernel.sysctl = {
      "kernel.panic" = 10;
      "kernel.panic_on_oops" = 1;
    };

    kernelPackages = pkgs.linuxPackages_latest;

    # ThinkPad-specific kernel parameters to fix lid/resume freeze
    kernelParams = [
      # Intel graphics fixes - minimal changes for better battery life
      "i915.panel_use_ssc=0" # Alternative fix for display issues
      "i915.enable_guc=3" # Enable GuC for better GPU power management
      "i915.enable_psr=1"
      "i915.enable_fbc=1"
      "i915.fastboot=1"
      "nvme_core.default_ps_max_latency_us=55000"

      # ACPI and sleep fixes
      "acpi_osi=\"Windows 2020\"" # Better ThinkPad ACPI compatibility
      "mem_sleep_default=deep" # Ensure proper S3 sleep state
      "acpi_sleep=s3_bios" # Use BIOS S3 sleep method
    ];
  };
}
