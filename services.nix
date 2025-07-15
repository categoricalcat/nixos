# Services configuration module

{ config, pkgs, ... }:

{
  # Printing service
  services.printing.enable = true;

  # Code-server
  services.code-server.enable = true;

  # OpenSSH daemon
  services.openssh = {
    enable = true;
    ports = [ 24212 ];
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = true;
      ChallengeResponseAuthentication = true;
      AuthenticationMethods = "publickey keyboard-interactive";
    };
  };

  # PAM configuration for SSH with Google Authenticator
  security.pam = {
    services.sshd.googleAuthenticator.enable = true;
  };

  # GnuPG agent
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # MTR network diagnostic tool
  programs.mtr.enable = true;
}
