# sops.nix
{
  lib,
  pkgs,
  ...
}:
let
  keys = import ./keys.nix;
in
{
  config = {
    # The /persist/keys permission layout, enforced at boot on every host
    # (and by `systemd-tmpfiles --create` in the DR drill after its fresh
    # disk is mounted). The bootstrap scripts keep mkdir/chmod copies for
    # install-time use before a system exists (scripts/).
    systemd.tmpfiles.rules = [
      "d ${keys.paths.keysFolder} 0755 root root -"
      "d ${keys.paths.sopsDir} 0700 root root -"
    ];

    sops = {
      age.sshKeyPaths = [ keys.paths.sshHostKey ];
      age.generateKey = false;

      # This encrypted file is kept outside the flake source, so use the runtime path.
      defaultSopsFile = keys.paths.sopsDefaultFile;
      useSystemdActivation = true;
      validateSopsFiles = false;
    };

    # The payload is encrypted to the X25519 recipient from ssh-to-age.
    # SOPS_AGE_SSH_PRIVATE_KEY_FILE is a different identity (ssh-ed25519) and
    # cannot decrypt it. Root's zsh, including non-interactive, derives the
    # matching age key. The host key is 0600 root:root.
    programs.zsh.shellInit = ''
      if [ "$(id -u)" = 0 ] && [ -r ${keys.paths.sshHostKey} ]; then
        export SOPS_AGE_KEY="$(${lib.getExe pkgs.ssh-to-age} -private-key -i ${keys.paths.sshHostKey})"
      fi
    '';
  };
}
