{ lib, ... }:

{
  options.serverMode = {
    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable headless server mode (disables GUI)";
    };
  };
}
