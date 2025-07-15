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

      # Performance optimizations
      # UseDNS = false; # Already set by default, but explicitly disable for faster connections
      Compression = false; # Disable compression - it hurts performance on fast networks
      TCPKeepAlive = true; # Detect dead connections
      ClientAliveInterval = 60; # Send keepalive every 60 seconds
      ClientAliveCountMax = 3; # Disconnect after 3 missed keepalives

      # Cipher and algorithm optimizations (fastest first)
      Ciphers = [
        "chacha20-poly1305@openssh.com" # Fast on modern CPUs
        "aes128-gcm@openssh.com" # Hardware accelerated on most CPUs
        "aes256-gcm@openssh.com" # Secure but slightly slower
        "aes128-ctr" # Fallback
        "aes256-ctr" # Fallback
      ];

      KexAlgorithms = [
        "curve25519-sha256" # Fast and secure
        "curve25519-sha256@libssh.org" # Alternative implementation
        "diffie-hellman-group-exchange-sha256"
      ];

      # Use faster MACs
      Macs = [
        "umac-128-etm@openssh.com" # Fastest
        "hmac-sha2-256-etm@openssh.com" # Good balance
        "hmac-sha2-512-etm@openssh.com" # More secure but slower
      ];
    };

    # Additional performance settings
    extraConfig = ''
      # Enable connection multiplexing for faster subsequent connections
      MaxSessions 10
      MaxStartups 10:30:100

      # Faster SFTP (if using internal-sftp)
      Subsystem sftp internal-sftp
    '';
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
