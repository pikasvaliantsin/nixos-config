{ pkgs, ... }:

{
  # ========================================
  # POWER MANAGEMENT
  # ========================================
  # Адаптивное управление частотой CPU (performance от сети, powersave от батареи)
  services.auto-cpufreq = {
    enable = true;
    settings = {
      charger = {
        governor = "performance";
        turbo = "auto";
      };
      battery = {
        governor = "powersave";
        turbo = "never";
      };
    };
  };

  # Отключаем power-profiles-daemon — конфликтует с auto-cpufreq
  services.power-profiles-daemon.enable = false;

  # ========================================
  # AUDIO / BLUETOOTH
  # ========================================
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
  };
  security.rtkit.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # ========================================
  # DESKTOP SERVICES
  # ========================================
  services.flatpak.enable = true;
  services.upower.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  programs.kdeconnect = {
    enable = true;
    package = pkgs.kdePackages.kdeconnect-kde;
  };

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Обслуживание SSD (TRIM)
  services.fstrim.enable = true;
}
