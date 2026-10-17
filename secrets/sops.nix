# sops.nix
_:
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

    # Let the sops CLI (as root) derive its age identity directly from the host SSH key.
    # Unprivileged users cannot read /persist/keys/ssh/ssh_host_ed25519_key (0600 root:root).
    environment.variables.SOPS_AGE_SSH_PRIVATE_KEY_FILE = keys.paths.sshHostKey;
  };
}
