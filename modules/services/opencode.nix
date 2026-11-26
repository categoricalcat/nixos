{
  pkgs,
  lib,
  config,
  allAddresses,
  systemdHardening,
  ...
}:

let
  opencodeHome = config.users.users.yi.home;
  opencodeConfigHome = "${opencodeHome}/.config";
  opencodeConfigPath = "${opencodeConfigHome}/opencode/opencode.json";
  host = allAddresses.hosts.${config.networking.hostName};
  ingressCredential = "opencode-ingress-credential";
in
{
  options.services.opencode = {
    enable = lib.mkEnableOption "Opencode Serve daemon";
  };

  config = lib.mkIf config.services.opencode.enable {
    sops.secrets."passwords/opencode" = { };
    # Both readers take the password: the daemon from the template, the ingress
    # credential from the secret file itself. Rotating it must restart both.
    sops.templates."opencode.env" = {
      content = ''
        OPENCODE_PASSWORD=${config.sops.placeholder."passwords/opencode"}
      '';
      restartUnits = [
        "opencode.service"
        "opencode-ingress-credential.service"
      ];
    };

    # opencode serve has no unauthenticated mode, and the Authelia gate is
    # the only login a person sees: the local ingress presents the server
    # password on every request yirukou forwards. A glob include, so a missing
    # credential costs opencode a 401 rather than the whole ingress its start.
    services.nginx.virtualHosts.${host.services.opencode.domain}.locations."/".extraConfig = ''
      include /run/${ingressCredential}/*.conf;
    '';

    systemd.services.${ingressCredential} = {
      description = "Basic credential the local ingress presents to opencode";
      # A restart of nginx starts its wants first, so the file exists whenever
      # nginx reads its configuration.
      wantedBy = [ "nginx.service" ];
      before = [ "nginx.service" ];
      wants = [ "sops-install-secrets.service" ];
      after = [ "sops-install-secrets.service" ];
      script = ''
        printf 'proxy_set_header Authorization "Basic %s";\n' \
          "$(printf 'opencode:%s' "$(cat "$CREDENTIALS_DIRECTORY/password")" | base64 --wrap=0)" \
          >"$RUNTIME_DIRECTORY/basic-auth.conf"
      '';
      serviceConfig = systemdHardening // {
        Type = "oneshot";
        RemainAfterExit = true;
        User = config.services.nginx.user;
        Group = config.services.nginx.group;
        LoadCredential = "password:${config.sops.secrets."passwords/opencode".path}";
        RuntimeDirectory = ingressCredential;
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = true;
        UMask = "0077";
      };
    };

    systemd.services.opencode = {
      description = "Opencode Serve Daemon";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      # The unit runs as yi but only sees the system PATH, not the user
      # profile, so the search tools the agent policies rely on are pinned here.
      path = [
        pkgs.fd
        pkgs.ripgrep
        pkgs.jq
        pkgs.curl
        pkgs.git
      ];

      # HM activation relinks opencode.json without changing this unit, so a
      # switch never restarts the daemon and it serves stale config. Restart
      # whenever the opencode settings change.
      restartTriggers = [
        (builtins.toJSON config.home-manager.users.yi.programs.opencode.settings)
      ];

      # The agent's job is running arbitrary user commands in home dirs: no
      # ProtectHome, ProtectSystem stays full (not strict), and bun's JIT,
      # spawned PTYs and sandboxed tools need the relaxed entries removed.
      serviceConfig =
        removeAttrs systemdHardening [
          "MemoryDenyWriteExecute"
          "ProtectHome"
          "PrivateDevices"
          "RestrictNamespaces"
        ]
        // {
          ProtectSystem = "full";
          EnvironmentFile = config.sops.templates."opencode.env".path;
          ExecStart = "${pkgs.opencode}/bin/opencode serve --port ${toString host.services.opencode.port} --hostname 127.0.0.1";
          Restart = "on-failure";
          RestartSec = 5;
          User = "yi";
          Group = "yi";
        };

      environment = {
        HOME = opencodeHome;
        XDG_CONFIG_HOME = opencodeConfigHome;
        OPENCODE_CONFIG = opencodeConfigPath;
      };
    };
  };
}
