{ lib, pkgs, ... }:

let
  dataDir = "/var/lib/terraria";
  worldDir = "${dataDir}/Worlds";
  worldFile = "${worldDir}/world.wld";
  configPath = "${dataDir}/serverconfig.txt";

  port = 7777;
  maxPlayers = 5;
in
{
  users.groups.terraria = { };
  users.users.terraria = {
    isSystemUser = true;
    group = "terraria";
    home = dataDir;
    createHome = true;
    description = "Terraria dedicated server user";
  };

  systemd.services.terraria = {
    description = "Terraria Dedicated Server";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    preStart = ''
            set -euo pipefail

            install -d -m 0750 -o terraria -g terraria ${dataDir} ${worldDir}

            umask 0027
            cat > ${configPath} <<EOF
      worldpath=${worldDir}
      world=${worldFile}
      port=${toString port}
      maxplayers=${toString maxPlayers}
      EOF

            chown terraria:terraria ${configPath}
            chmod 0640 ${configPath}
    '';

    serviceConfig = {
      Type = "simple";
      User = "terraria";
      Group = "terraria";
      WorkingDirectory = dataDir;
      Restart = "on-failure";
      RestartSec = "5s";
    };

    script = ''
      exec ${lib.getExe pkgs.terraria-server} -config ${configPath}
    '';
  };

  networking.firewall.allowedTCPPorts = [ port ];
  networking.firewall.allowedUDPPorts = [ port ];
}
