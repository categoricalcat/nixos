# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "fufuwuqi";

    networkmanager.enable = false;
    useNetworkd = true;
    useDHCP = false;

    firewall = {
      enable = true;
      allowedTCPPorts = [
        24212
        3000
        3001
        9000
      ];
    };
  };

  systemd.network = {
    enable = true;
    netdevs = {
      "10-bond0" = {
        netdevConfig = {
          Kind = "bond";
          Name = "bond0";
        };
        bondConfig = {
          Mode = "active-backup"; # In the 802.3ad mode, I was getting huge log spam about link speed and duplex mode not being determined.
          MIIMonitorSec = "0.100"; # Unplugging the Ethernet cable turned full-duplex mode into half-duplex mode in /proc/net/bonding/bond0, but didn't fail over to enp4s0.
          PrimaryReselectPolicy = "better"; # Fixes recovery after plugging in USB eno1
        };
      };
    };
    networks = {
      "30-eno1" = {
        matchConfig.Name = "eno1";
        networkConfig.Bond = "bond0";
        networkConfig.PrimarySlave = true; # without this line, unplugging and replugging the USB ethernet adapter would not reactivate the eno1 route. Curiously, unplugging/replugging the Ethernet cable itself still worked fine.
      };

      "30-enp4s0" = {
        matchConfig.Name = "enp4s0";
        networkConfig.Bond = "bond0";
      };

      "40-bond0" = {
        matchConfig.Name = "bond0";
        linkConfig.RequiredForOnline = "carrier";
        networkConfig.DHCP = "yes";
      };
    };
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Set your time zone.
  time.timeZone = "America/Sao_Paulo";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "alt-intl";
  };

  # Configure console keymap
  console.keyMap = "us";

  services.printing.enable = true;
  services.code-server.enable = true;

  services.pulseaudio.enable = false;
  # services.pipewire.enable = false;
  security.rtkit.enable = false;

  users.users.fufud = {
    isNormalUser = true;
    description = "fufuwuqi";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
    ];
    packages = with pkgs; [
      chromium
    ];
  };

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "fufud";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = true;
  systemd.services."autovt@tty1".enable = true;
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    wget
    btop
    curl
    emacs
    git
    gh
    google-authenticator
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
    vscode
    nixfmt-rfc-style
    nodejs_24
  ];

  environment.pathsToLink = [ "/share/zsh" ];

  environment.variables = {
    # ZSH_DISABLE_COMPFIX = "true";
    ZSH_COMPDUMP = "$HOME/.zcomp/zcompdump-$HOST";
  };

  users.defaultUserShell = pkgs.zsh;

  # Some programs need SUID wrappers, can be configured further or are
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
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

  security.pam = {
    services.sshd.googleAuthenticator.enable = true;
  };

  programs.zsh = {
    enable = true;
    ohMyZsh = {
      enable = true;
      plugins = [
        "git"
        "sudo"
        "docker"
      ];
      theme = "agnoster";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
