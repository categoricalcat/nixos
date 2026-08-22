{ lib, ... }:

{
  options.serverMode = {
    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable headless server mode (disables GUI)";
    };
    developer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include developer tooling in the home-manager profile on headless hosts";
    };
    tui = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include terminal UI and productivity tools";
    };
  };
}
