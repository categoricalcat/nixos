{ config, lib, ... }:

let
  hostname = config.networking.hostName;

  allDevices = {
    yifuwuqi = {
      id = "KXQDLTO-SB3I6R6-LHU7L4S-KY5J62X-EHVRZ5X-QQJASVO-IXWJDMP-6AAKPQC";
    };
    yitaishi = {
      id = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX"; # TODO: replace after first deploy
    };
    yixiaoqing = {
      id = "T3F3CMH-5BZC3CP-JRBCERD-B565D7H-AFJQXOC-KPME3D6-VR3QSA7-PTCBAAF";
    };
    yishouji = {
      id = "2VM5PW2-NZAJTUH-4QNGWSP-AOH32GO-GRRNVL3-UMH76M3-45V6KCI-V7SMPAI";
    };
  };

  allFolders = {
    obsidian = {
      path = "/home/yi/obsidian";
      devices = [
        "yifuwuqi"
        "yitaishi"
        "yixiaoqing"
        "yishouji"
      ];
    };
  };

  otherDevices = lib.filterAttrs (n: _: n != hostname) allDevices;

  folders = lib.mapAttrs (
    _: f:
    f
    // {
      devices = builtins.filter (d: d != hostname) f.devices;
    }
  ) allFolders;

  isServer = hostname == "yifuwuqi";
in
{
  services.syncthing = {
    enable = true;
    user = "yi";
    group = "users";
    dataDir = "/home/yi";
    openDefaultPorts = true;
    guiAddress = if isServer then "0.0.0.0:8384" else "127.0.0.1:8384";

    overrideDevices = false;
    overrideFolders = false;

    settings = {
      devices = otherDevices;
      inherit folders;
    };
  };

  systemd.tmpfiles.rules = lib.mapAttrsToList (_: f: "d ${f.path} 0750 yi users -") allFolders;
}
