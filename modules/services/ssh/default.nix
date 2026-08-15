{
  addresses,
  allAddresses,
  config,
  lib,
  pkgs,
  ...
}:
let
  keys = import ../../../secrets/keys.nix;
  listenWildcardIPv4 = addresses.ssh.listenWildcardIPv4 or null;
  listenWildcardIPv6 = addresses.ssh.listenWildcardIPv6 or null;
  dynamicSshConfig = import ./dynamic.nix { inherit lib allAddresses keys; };

  aiGate = pkgs.writeShellScript "ai-gate" (builtins.readFile ./scripts/ai-gate.sh);
in
{
  imports = [ ./known-hosts.nix ];

  systemd.services.sshd = {
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "time-sync.target"
    ]
    # ++ (lib.optional config.services.tailscale.enable "tailscaled.service")
    ++ (lib.optional config.services.netbird.enable "netbird.service");

    startLimitIntervalSec = 0;
    serviceConfig.RestartSec = "2s";

    preStart = lib.mkBefore ''
      if [ ! -s ${keys.paths.sshHostKey} ]; then
        echo "Missing persisted SSH host key: ${keys.paths.sshHostKey}" >&2
        echo "Refusing to generate a new host/SOPS identity automatically." >&2
        exit 1
      fi
    '';
  };

  services.openssh = {
    enable = true;
    ports = [ addresses.ssh.listenPort ];

    hostKeys = [
      {
        path = keys.paths.sshHostKey;
        type = "ed25519";
      }
    ];

    listenAddresses =
      (map (addr: {
        inherit addr;
        port = addresses.ssh.listenPort;
      }) addresses.ssh.listenAddresses)
      ++ (
        if listenWildcardIPv4 != null then
          [
            {
              addr = listenWildcardIPv4;
              port = addresses.ssh.listenPort;
            }
          ]
        else
          [ ]
      )
      ++ (
        if listenWildcardIPv6 != null then
          [
            {
              addr = listenWildcardIPv6;
              port = addresses.ssh.listenPort;
            }
          ]
        else
          [ ]
      );

    settings = {
      AllowUsers = [
        "yi"
        "workd"
        "nix-builder"
        "ai"
      ];
      PermitRootLogin = "no";
      GatewayPorts = "yes";
      # Password auth is off globally; re-enabled only for LAN clients below.
      PasswordAuthentication = false;
    };

    # Additional performance settings
    extraConfig = ''
      MaxSessions 20
      # MaxStartups 10:30:100

      # Faster SFTP (if using internal-sftp)
      Subsystem sftp internal-sftp

      # LAN clients (10.42.0.0/24) keep password auth; ts/nb/cloudflared do not.
      # Match Address matches the client source address.
      Match Address 10.42.0.0/24
        PasswordAuthentication yes

      Match User nix-builder
        AuthenticationMethods publickey
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        X11Forwarding no
        AllowTcpForwarding no
        AllowAgentForwarding no
        AllowStreamLocalForwarding no
        PermitTTY no
        PermitOpen none
        ForceCommand nix-daemon --stdio

      Match User ai
        AuthenticationMethods publickey
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        X11Forwarding no
        AllowTcpForwarding no
        AllowAgentForwarding no
        AllowStreamLocalForwarding no
        PermitTTY no
        ForceCommand ${aiGate}
    '';
  };

  programs.ssh.extraConfig = builtins.readFile ../../../users/assets/dotfiles/ssh/config + ''
    ${dynamicSshConfig}
  '';

  programs.mosh.enable = true;
}
