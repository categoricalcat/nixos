{ lib, ... }:

{
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = lib.mkDefault "--delete-older-than 9d";
    };

    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      download-buffer-size = lib.mkDefault (1024 * 1024 * 1024 * 10);

      substituters = [
        "https://nix-community.cachix.org"
        "https://nixos-rocm.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "nixos-rocm.cachix.org-1:VEpsf7pRIijjd8csKjFNBGzkBqOmw8H9PRmgAq14LnE"
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
