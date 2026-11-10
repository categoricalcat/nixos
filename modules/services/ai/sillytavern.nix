{
  config,
  lib,
  pkgs,
  allAddresses,
  systemdHardening,
  ...
}:

let
  yifuwuqiServices = allAddresses.hosts.yifuwuqi.services;
  cfg = config.yi.services.sillytavern;
in
{
  options.yi.services.sillytavern = {
    enable = lib.mkEnableOption "SillyTavern local AI companion";
  };

  config = lib.mkIf cfg.enable {
    users.users.sillytavern = {
      isSystemUser = true;
      group = "sillytavern";
    };
    users.groups.sillytavern = { };

    systemd.services.sillytavern = {
      description = "Silly Tavern";
      after = [
        "network.target"
        "llama-cpp-qwen3-6-35b-abliterated.service"
      ];
      wants = [ "llama-cpp-qwen3-6-35b-abliterated.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = "/var/lib/SillyTavern";
        XDG_DATA_HOME = "/var/lib";
      };

      preStart = ''
        if [ -L /var/lib/SillyTavern/config.yaml ]; then
          rm -f /var/lib/SillyTavern/config.yaml
        fi

        # Ensure config.yaml exists before modifying
        if [ ! -f /var/lib/SillyTavern/config.yaml ]; then
          # Start and immediately kill to generate default config
          ${pkgs.sillytavern}/bin/sillytavern --port=${toString yifuwuqiServices.sillytavern.port} &
          ST_PID=$!
          sleep 3
          kill $ST_PID || true
        fi

      '';

      serviceConfig = {
        # Client-facing hosted service (companion.aset.love) behind the local
        # ingress: loopback-only, so no --listen. The whitelist checks the
        # forwarded client IP and would 403 LAN clients behind two proxy hops,
        # so it stays disabled; loopback keeps it safe.
        ExecStart = "${pkgs.sillytavern}/bin/sillytavern --port=${toString yifuwuqiServices.sillytavern.port} --no-whitelist";
        User = "sillytavern";
        Group = "sillytavern";
        StateDirectory = "SillyTavern";
        WorkingDirectory = "/var/lib/SillyTavern";

        Restart = "always";
        Type = "simple";
      }
      # Node.js JIT needs writable executable mappings, and its fs layer
      # chowns (@chown sits outside @system-service; same exception as the
      # Arr apps in servarrHardening).
      // removeAttrs systemdHardening [ "MemoryDenyWriteExecute" ]
      // {
        SystemCallFilter = lib.splitString " " "@system-service ~@privileged @chown";
      };
    };
  };
}
