{
  lib,
  allAddresses,
  keys,
}:
let
  mkSshRewrite =
    host: alias:
    let
      ip = lib.attrByPath alias.path null host;
    in
    lib.optionalString (ip != null && (host.ssh.listenPort or null) != null) ''
      Host ${host.hostName}.${alias.suffix}
          HostName ${ip}
          Port ${toString host.ssh.listenPort}
    '';

  # Bare-name routing so `ai-ssh <host> <command>` resolves. Prefer the LAN
  # address when the host has one (yifuwuqi, yirukou), otherwise fall back to
  # the tailscale address (yitaishi, yixiaoqing accept ssh only via VPN).
  mkBareRewrite =
    host:
    let
      lanIp = lib.attrByPath [ "network" "lan" "ipv4" "host" ] null host;
      ip = if lanIp != null then lanIp else host.network.vpn.ipv4.host;
    in
    lib.optionalString ((host.ssh.listenPort or null) != null) ''
      Host ${host.hostName}
          HostName ${ip}
          Port ${toString host.ssh.listenPort}
    '';

  dynamicSshConfig = lib.concatStringsSep "\n" (
    builtins.concatMap (
      host: [ (mkBareRewrite host) ] ++ (map (alias: mkSshRewrite host alias) allAddresses.aliases)
    ) (builtins.attrValues allAddresses.hosts)
  );
in
''
  IdentityFile ${keys.paths.userGitSshKey "~"}

  Match User root
      IdentityFile ${keys.paths.sshHostKey}

  ${dynamicSshConfig}
''
