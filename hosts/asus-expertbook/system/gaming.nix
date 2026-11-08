{
  pkgs,
  config,
  ...
}:

let
  # Привилегированный тюнинг, недоступный обычному пользователю.
  # Вызывается из GameMode (start/end) через `sudo -n`: см. security.sudo.extraRules.
  #
  # 1. platform_profile — профиль EC/BIOS ASUS. На ExpertBook "balanced" режет
  #    package power (~15 Вт на CPU+iGPU), "performance" поднимает лимит и
  #    обороты вентилятора. Для APU это напрямую решает, сколько ватт получит Vega 7.
  # 2. power_dpm_force_performance_level — держит GPU на максимальных частотах
  #    (1800 МГц) без провалов между кадрами.
  # 3. vm.swappiness — на время игры не даём ядру вытеснять память игры в zRAM
  #    (в остальное время остаётся агрессивный профиль из boot.nix).
  powerTune = pkgs.writeShellScriptBin "cs2-power-tune" ''
    export PATH="${pkgs.coreutils}/bin"

    set -eu

    state=/run/cs2-power-tune
    profile=/sys/firmware/acpi/platform_profile

    dpm=""
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
      if [ -w "$f" ]; then dpm="$f"; fi
    done

    case "''${1:-}" in
      start)
        mkdir -p "$state"
        if [ -w "$profile" ]; then
          cat "$profile" > "$state/platform_profile"
          echo performance > "$profile"
        fi
        if [ -n "$dpm" ]; then echo high > "$dpm"; fi
        cat /proc/sys/vm/swappiness > "$state/swappiness"
        echo 100 > /proc/sys/vm/swappiness
        ;;
      stop)
        if [ -s "$state/platform_profile" ] && [ -w "$profile" ]; then
          cat "$state/platform_profile" > "$profile"
        fi
        if [ -n "$dpm" ]; then echo auto > "$dpm"; fi
        if [ -s "$state/swappiness" ]; then
          cat "$state/swappiness" > /proc/sys/vm/swappiness
        fi
        ;;
      *)
        echo "usage: $0 start|stop" >&2
        exit 2
        ;;
    esac
  '';
in
{
  programs = {
    # Системный Steam с расширенным FHS-рантаймом
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
      package = pkgs.steam.override {
        extraPkgs = import ./steam-extra-pkgs.nix;
      };
    };

    # GameMode: авто-оптимизация при запуске игр (приоритет, governor, CPU boost)
    # + Gamescope: изоляция игровых процессов от Wayland-композитора
    gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10; # Приоритет процесса игры (нужна группа gamemode)
          inhibit_screensaver = 1;
          # Снимает #AC-ловушку на split-lock операциях (Wine/Proton, античиты).
          disable_splitlock = 1;
          softrealtime = "off";
        };

        # GPU-тюнинг делаем сами в powerTune: amd_performance_level в gamemode
        # ходит через pkexec, что в неинтерактивной сессии лишний риск.
        cpu = {
          park_cores = "no";
          pin_cores = "no";
        };

        custom = {
          start = "${config.security.wrapperDir}/sudo -n ${powerTune}/bin/cs2-power-tune start";
          end = "${config.security.wrapperDir}/sudo -n ${powerTune}/bin/cs2-power-tune stop";
        };
      };
    };

    gamescope.enable = true;
  };

  # gamescope в nested-режиме просит CAP_SYS_NICE для realtime-потоков.
  # Без него в логе: "No CAP_SYS_NICE ... Performance will be affected",
  # и композитор пейсит кадры с обычным приоритетом — отсюда рваность.
  security.wrappers.gamescope = {
    source = "${pkgs.gamescope}/bin/gamescope";
    capabilities = "cap_sys_nice+ep";
    owner = "root";
    group = "root";
  };

  # Доступ к /dev/uinput для reel-hold (удержание физического keycode).
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660"
  '';

  # input-remapper: системный демон маппинга геймпада на клавиатуру/мышь
  # (замена постоянно запущенному antimicrox).
  services.input-remapper = {
    enable = true;
    enableUdevRules = true;
  };

  # Стрим на телефон: Sunshine (хост) + Moonlight (клиент).
  # niri — wlroots, поэтому захват через wlr-screencopy; кодирование VAAPI.
  services.sunshine = {
    enable = true;
    openFirewall = true;

    settings = {
      sunshine_name = "asus-expertbook";
      capture = "wlr";
      encoder = "vaapi";
      output_name = "HDMI-A-1";
      # Стабильный профиль виртуального геймпада. В evdev устройство видно
      # как "Sunshine (libvirtualhid) X-Box Series Controller" — от этого имени
      # зависит preset input-remapper.
      gamepad = "xseries";
    };

    applications = {
      env.PATH = "$(PATH):/etc/profiles/per-user/valen/bin";
      apps = [
        {
          # Просто текущий экран: подходит, если игра уже запущена.
          name = "Desktop";
        }
        {
          name = "RF4";
          cmd = "rf4-stream";
          "auto-detach" = "true";
        }
      ];
    };
  };

  # Штатная polkit-политика gamemode объявляет allow_active=no, поэтому
  # переключение governor и /proc/sys через pkexec в игре требует пароль и
  # молча не срабатывает. Разрешаем это членам группы gamemode.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.isInGroup("gamemode") &&
          (action.id == "com.feralinteractive.GameMode.governor-helper" ||
           action.id == "com.feralinteractive.GameMode.procsys-helper" ||
           action.id == "com.feralinteractive.GameMode.gpu-helper")) {
        return polkit.Result.YES;
      }
    });
  '';

  # NOPASSWD строго на один скрипт. Он принимает только start|stop и пишет
  # лишь в platform_profile, amdgpu DPM и vm.swappiness.
  security.sudo.extraRules = [
    {
      users = [ "valen" ];
      commands = [
        {
          command = "${powerTune}/bin/cs2-power-tune";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
