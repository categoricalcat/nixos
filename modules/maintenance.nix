{ config, lib, ... }:

let
  inherit (config.yi.maintenance) slots;

  slot = calendar: jitter: rec {
    inherit calendar jitter;
    timerConfig = {
      RandomizedDelaySec = lib.mkForce jitter;
      FixedRandomDelay = true;
      AccuracySec = "1m";
    };
    timer = {
      wantedBy = [ "timers.target" ];
      timerConfig = timerConfig // {
        OnCalendar = calendar;
        Persistent = true;
      };
    };
  };

  nhClean = config.programs.nh.clean.enable;
  podmanPrune = config.virtualisation.podman.autoPrune.enable;
  dockerPrune = config.virtualisation.docker.autoPrune.enable;
  fstrim = config.services.fstrim.enable;
  btrfsScrub = config.services.btrfs.autoScrub.enable;
  recyclarr = config.services.recyclarr.enable;

  idleUnits =
    lib.optional nhClean "nh-clean"
    ++ lib.optional dockerPrune "docker-prune"
    ++ lib.optional fstrim "fstrim";

  fstrimAfter =
    lib.optional nhClean "nh-clean.service"
    ++ lib.optional podmanPrune "podman-prune.service"
    ++ lib.optional dockerPrune "docker-prune.service";
in
{
  options.yi.maintenance.slots = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    readOnly = true;
    default = {
      backups = slot "*-*-* 01:30:00" "5m";
      nixGc = slot "Mon *-*-* 02:00:00" "10m";
      autoMaintenance = slot "*-*-* 02:30:00" "5m";
      podmanAutoUpdate = slot "*-*-* 03:30:00" "15m";
      containerPrune = slot "Mon *-*-* 04:00:00" "10m";
      recyclarr = slot "*-*-* 04:15:00" "5m";
      atticGc = slot "*-*-* 04:30:00" "5m";
      fstrim = slot "Mon *-*-* 04:45:00" "10m";
      cveScan = slot "*-*-* 05,17:30:00" "15m";
      gluetunRotate = slot "*-*-* 00/6:00:00" "5m";
    };
    description = "Fleet maintenance timetable; every slot-driven timer takes its calendar and delay from here";
  };

  config = lib.mkMerge [
    {
      programs.nh.clean.dates = slots.nixGc.calendar;

      services = {
        fstrim.interval = slots.fstrim.calendar;
        btrfs.autoScrub.enable = lib.mkDefault (
          lib.any (fs: fs.fsType == "btrfs") (lib.attrValues config.fileSystems)
        );
        smartd.defaults.monitored = "-a -s (S/../../7/05|L/../0[1-7]/7/05)";
        recyclarr.schedule = slots.recyclarr.calendar;
      };

      virtualisation.docker.autoPrune = lib.mkIf config.virtualisation.docker.enable {
        enable = true;
        dates = slots.containerPrune.calendar;
        randomizedDelaySec = slots.containerPrune.jitter;
        flags = [
          "--all"
          "--filter"
          "until=168h"
        ];
      };

      systemd = {
        timers = {
          nh-clean = lib.mkIf nhClean { inherit (slots.nixGc) timerConfig; };
          fstrim = lib.mkIf fstrim { inherit (slots.fstrim) timerConfig; };
          docker-prune = lib.mkIf dockerPrune { inherit (slots.containerPrune) timerConfig; };
          recyclarr = lib.mkIf recyclarr { inherit (slots.recyclarr) timerConfig; };
        };
        services = {
          fstrim = lib.mkIf (fstrim && fstrimAfter != [ ]) { after = fstrimAfter; };
          docker-prune = lib.mkIf (dockerPrune && nhClean) { after = [ "nh-clean.service" ]; };
          "btrfs-scrub@" = lib.mkIf (btrfsScrub && nhClean) { after = [ "nh-clean.service" ]; };
        };
      };
    }

    (lib.mkIf (!config.serverMode.headless) {
      systemd.services = lib.genAttrs idleUnits (_: {
        serviceConfig = {
          Nice = 19;
          IOSchedulingClass = "idle";
          CPUSchedulingPolicy = "idle";
        };
        unitConfig = lib.mkIf config.services.tlp.enable { ConditionACPower = true; };
      });
    })
  ];
}
