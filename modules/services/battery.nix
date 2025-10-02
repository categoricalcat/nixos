_: {
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 20;

      #Opcional ajuda a economizar a saúde da bateria a longo prazo
      START_CHARGE_THRESH_BAT1 = 40; # 40 e abaixo, começa a carregar
      STOP_CHARGE_THRESH_BAT1 = 80; # 80 e acima, para de carregar
    };
  };
}
