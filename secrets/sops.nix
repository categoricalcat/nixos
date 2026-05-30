# sops.nix
{
  config,
  ...
}:
let
  keys = import ./keys.nix;
in
{
  config = {
    sops.age.sshKeyPaths = [ keys.paths.sshHostKey ];
    sops.age.generateKey = false;

    # This encrypted file is kept outside the flake source, so use the runtime path.
    sops.defaultSopsFile = keys.paths.sopsDefaultFile;
    sops.useSystemdActivation = true;
    sops.validateSopsFiles = false;

    # Let the sops CLI derive an age identity from the user's SSH key
    environment.variables.SOPS_AGE_SSH_PRIVATE_KEY_FILE =
      keys.paths.userSshKey config.users.users.yi.home;
  };
}
