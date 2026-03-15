{
  imports = [
    ../../modules/services/zerotier.nix
  ];

  services.ollama = {
    enable = true;
  };
}
