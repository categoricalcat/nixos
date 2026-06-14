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

  dynamicSshConfig = lib.concatStringsSep "\n" (
    lib.concatMap (host: map (alias: mkSshRewrite host alias) allAddresses.aliases) (
      builtins.attrValues allAddresses.hosts
    )
  );
in
''
  IdentityFile ${keys.paths.userGitSshKey "~"}

  ${dynamicSshConfig}
''
