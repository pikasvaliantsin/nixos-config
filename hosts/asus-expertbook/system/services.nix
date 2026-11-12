_:

{
  # ========================================
  # POWER MANAGEMENT
  # ========================================
  services = {
    # Адаптивное управление частотой CPU (performance от сети, powersave от батареи)
    auto-cpufreq = {
      enable = true;
      settings = {
        charger = {
          governor = "performance";
          # turbo=auto НЕ возвращает boost после работы от батареи: секция
          # battery ставит turbo=never, а "auto" просто не трогает значение.
          # Итог — на зарядке CPU живёт на 2.3 ГГц вместо 4.35 ГГц.
          turbo = "always";
        };
        battery = {
          governor = "powersave";
          turbo = "never";
        };
      };
    };

    # Отключаем power-profiles-daemon — конфликтует с auto-cpufreq
    power-profiles-daemon.enable = false;

    # ========================================
    # AUDIO
    # ========================================
    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
    };

    # ========================================
    # DESKTOP SERVICES
    # ========================================
    upower.enable = true;
    udisks2.enable = true;
    gvfs.enable = true;
    fstrim.enable = true; # Обслуживание SSD (TRIM)

    gnome.gnome-keyring.enable = true;
  };

  security = {
    rtkit.enable = true;
    pam.services.greetd.enableGnomeKeyring = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
