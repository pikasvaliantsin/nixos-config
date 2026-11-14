{ pkgs, ... }:

{
  # ========================================
  # POWER MANAGEMENT
  # ========================================
  # Частота CPU и профиль EC задаются явным oneshot-сервисом.
  #
  # Раньше здесь был auto-cpufreq, но на этом железе он не мог работать:
  #   - BIOS L2502CYA.310 не отдаёт _CPC, amd_pstate не грузится, остаётся
  #     acpi-cpufreq без EPP (см. `journalctl -k | grep _CPC`);
  #   - governor "powersave" удалён из ядра 6.13, доступны только
  #     performance/schedutil, поэтому секция battery молча не применялась;
  #   - демон хотел scaling_max_freq=4.35 ГГц, а acpi-cpufreq даёт 2.3 ГГц +
  #     отдельный boost, и каждую секунду повторял неудачную запись.
  #
  # schedutil даёт 1.6 ГГц в простое и те же 4.35 ГГц под нагрузкой: пик не
  # режется, уходит только холостой буст.
  #
  # Важно: декларативный boot.kernel.sysfs здесь НЕ используется. Его
  # PathExistsGlob-вотчеры на 26.11 не запускают setter-юниты (проверено:
  # пустой ExecMainStartTimestamp и ноль записей в журнале), поэтому значения
  # молча не применялись. Oneshot ниже выполняется всегда и виден в journalctl.
  systemd.services.cpu-power-policy = {
    description = "Set CPU governor/boost and ACPI platform profile";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    path = [ pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      for gov in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
        echo schedutil > "$gov"
      done

      # boost оставляем включённым — ограничений по температуре не добавляем.
      if [ -w /sys/devices/system/cpu/cpufreq/boost ]; then
        echo 1 > /sys/devices/system/cpu/cpufreq/boost
      fi

      # asus-nb-wmi регистрирует platform_profile чуть позже, ждём до 10 c.
      n=0
      while [ "$n" -lt 20 ]; do
        if [ -w /sys/firmware/acpi/platform_profile ]; then
          echo balanced > /sys/firmware/acpi/platform_profile
          exit 0
        fi
        n=$((n + 1))
        sleep 0.5
      done
      echo "platform_profile не появился за 10 c, пропускаю" >&2
    '';
  };

  # Лимит заряда батареи ASUS. Порог хранится в EC (ACPI-хук
  # "ASUS Battery Extension"), поэтому действует и при выключенном ноуте,
  # пока подключён адаптер. Сбрасывается BIOS-обновлением, EC-reset и MyASUS
  # в Windows, поэтому переприменяем при загрузке и на событие адаптера.
  #
  # Start-порога на этой модели нет: если заряд уже выше 60, EC просто не
  # будет заряжать дальше. Чтобы опуститься до 60, нужно разрядить батарею
  # работой от неё один раз.
  systemd.services.battery-charge-limit = {
    description = "Apply ASUS battery charge limit (60%)";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      # RemainAfterExit не ставим: юнит должен оставаться inactive, иначе
      # SYSTEMD_WANTS из udev-правила ниже не сможет запустить его повторно.
    };
    script = ''
      set -eu

      threshold=/sys/class/power_supply/BAT0/charge_control_end_threshold
      if [ ! -w "$threshold" ]; then
        echo "charge threshold недоступен, пропускаю" >&2
        exit 0
      fi

      echo 60 > "$threshold"
      echo "charge limit: $(cat "$threshold")"
    '';
  };

  services = {
    # На этой машине без _CPC демону нечего предложить, кроме platform_profile,
    # а он конфликтует с настройкой выше. Не включаем.
    power-profiles-daemon.enable = false;

    # Переприменяем лимит заряда при подключении/отключении адаптера.
    # Реагируем именно на AC0: событие на BAT0 может быть следствием самой
    # записи порога и дать петлю перезапусков.
    udev.extraRules = ''
      SUBSYSTEM=="power_supply", KERNEL=="AC0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="battery-charge-limit.service"
    '';

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
