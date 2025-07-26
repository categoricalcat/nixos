# User configuration module

{ config, pkgs, ... }:

{
  # User accounts
  users.users.fufud = {
    isNormalUser = true;
    description = "fu's personal";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "render"
      "video"
      "docker"
    ];
    packages = with pkgs; [
    ];
  };

  users.users.workd = {
    isNormalUser = true;
    description = "fu's work";
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "docker"
    ];
    packages = with pkgs; [
      nodejs_20
    ];
  };

  # Default shell
  users.defaultUserShell = pkgs.zsh;

  # MTR network diagnostic tool
  programs.mtr.enable = true;

  # Zsh configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    # Configure Zsh shell
    interactiveShellInit = ''
      # Enable starship prompt
      eval "$(${pkgs.starship}/bin/starship init zsh)"

      # Enable direnv for automatic environment switching
      eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
    '';
  };

  # Starship prompt configuration
  programs.starship = {
    enable = true;
    # You can add custom settings here later
    settings = {
      # Example: simpler prompt format
      # format = "$all$character";
    };
  };

  environment.variables = {
    ZSH_COMPDUMP = "$HOME/.zcomp/zcompdump-$HOST";
  };

  environment.pathsToLink = [ "/share/zsh" ];
}
