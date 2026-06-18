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
    sops = {
      age.sshKeyPaths = [ keys.paths.sshHostKey ];
      age.generateKey = false;

      # This encrypted file is kept outside the flake source, so use the runtime path.
      defaultSopsFile = keys.paths.sopsDefaultFile;
      useSystemdActivation = true;
      validateSopsFiles = false;
    };

    # Let the sops CLI derive an age identity from the user's SSH key
    environment.variables.SOPS_AGE_SSH_PRIVATE_KEY_FILE = keys.paths.userSshKey config.users.users.yi.home;
  };
}
