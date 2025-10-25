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
      "vm.swappiness" = 80;
    };

    kernelPackages = pkgs.linuxPackages_latest;

    # ThinkPad-specific kernel parameters to fix lid/resume freeze
    kernelParams = [
      # Intel graphics fixes
      "i915.enable_psr=0" # Disable Panel Self Refresh (common freeze cause)
      "i915.enable_dc=0" # Disable display power saving
      "intel_idle.max_cstate=1" # Prevent deep C-states

      # ACPI and sleep fixes
      "acpi_osi=\"Windows 2020\"" # Better ThinkPad ACPI compatibility
      "mem_sleep_default=deep" # Ensure proper S3 sleep state
      "acpi_sleep=s3_bios" # Use BIOS S3 sleep method
    ];
  };
}
