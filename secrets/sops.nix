# sops.nix
{
  config,
  lib,
  ...
}:
let
  keys = import ./keys.nix;
  hostKeys = keys.hosts.${config.networking.hostName} or { };
  needsLegacyKey = (hostKeys.ageRecipient or null) == null;
in
{
  config = {
    sops.age.sshKeyPaths = [ keys.paths.sshHostKey ];
    sops.age.keyFile = lib.mkIf needsLegacyKey keys.paths.sopsFallbackKeyFile;

    # This encrypted file is kept outside the flake source, so use the runtime path.
    sops.defaultSopsFile = keys.paths.sopsDefaultFile;
    sops.useSystemdActivation = true;
    sops.validateSopsFiles = false;

    # Let the sops CLI derive an age identity from the user's SSH key
    environment.variables.SOPS_AGE_SSH_PRIVATE_KEY_FILE = keys.paths.userSshKey config.users.users.yi.home;
  };
}
