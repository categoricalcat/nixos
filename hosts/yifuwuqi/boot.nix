{
  lib,
  ...
}:

{

  boot = {
    loader = {
      systemd-boot.configurationLimit = 15;
    };

    initrd.availableKernelModules = lib.mkAfter [
      "sd_mod"
    ];

    initrd.kernelModules = lib.mkAfter [ "amdgpu" ];

    kernelModules = lib.mkAfter [
      "amdgpu"
      "wireguard"
      "nft_masq"
    ];
  };
}
