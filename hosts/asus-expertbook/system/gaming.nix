{
  pkgs,
  config,
  ...
}:

let
  # Привилегированный тюнинг на время игры. Вызывается из GameMode
  # (custom.start/end) через sudo -n; NOPASSWD выдан только на этот скрипт.
  #
  # 1. platform_profile — на ExpertBook "balanced" режет package power
  #    (~15 Вт на CPU+iGPU), "performance" поднимает лимит. Для APU это
  #    напрямую решает, сколько ватт получит Vega 7 и какой будет буст CPU.
  # 2. power_dpm_force_performance_level — держит GPU на высоких частотах.
  # 3. vm.swappiness — на время игры не даём ядру вытеснять память игры
  #    в zRAM (в остальное время остаётся профиль из boot.nix).
  gamePowerTune = pkgs.writeShellScriptBin "game-power-tune" ''
    export PATH="${pkgs.coreutils}/bin"
    set -eu

    state=/run/game-power-tune
    profile=/sys/firmware/acpi/platform_profile

    dpm=""
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
      if [ -w "$f" ]; then dpm="$f"; fi
    done

    case "''${1:-}" in
      start)
        # Не перезаписываем сохранённые значения при повторном start.
        if [ ! -d "$state" ]; then
          mkdir -p "$state"
          if [ -w "$profile" ]; then
            cat "$profile" > "$state/platform_profile"
            echo performance > "$profile"
          fi
          if [ -n "$dpm" ]; then echo high > "$dpm"; fi
          cat /proc/sys/vm/swappiness > "$state/swappiness"
          echo 100 > /proc/sys/vm/swappiness
        fi
        ;;
      stop)
        if [ -d "$state" ]; then
          if [ -s "$state/platform_profile" ] && [ -w "$profile" ]; then
            cat "$state/platform_profile" > "$profile"
          fi
          if [ -n "$dpm" ]; then echo auto > "$dpm"; fi
          if [ -s "$state/swappiness" ]; then
            cat "$state/swappiness" > /proc/sys/vm/swappiness
          fi
          rm -rf "$state"
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
  environment.systemPackages = [ gamePowerTune ];

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

    # GameMode: приоритет процессу игры и ингибирование скринсейвера
    # + Gamescope: изоляция игровых процессов от Wayland-композитора.
    # Governor больше не трогаем: им управляет schedutil из services.nix.
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

        cpu = {
          park_cores = "no";
          pin_cores = "no";
        };

        # gamemoderun запускает это до игры и после её выхода. sudo -n
        # разрешён только на game-power-tune (см. security.sudo ниже).
        custom = {
          start = "${config.security.wrapperDir}/sudo -n ${gamePowerTune}/bin/game-power-tune start";
          end = "${config.security.wrapperDir}/sudo -n ${gamePowerTune}/bin/game-power-tune stop";
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

    # RF4 (Unity/Proton) намертво виснет, когда в уже запущенную игру
    # подключают джойстик. Sunshine создаёт виртуальный геймпад при каждом
    # подключении телефона. Прячем его event/js/hidraw-узлы от пользовательских
    # процессов (игра/Wine), но оставляем доступным input-remapper: он работает
    # от root, забирает геймпад и отдаёт игре клавиатуру/мышь.
    # Так можно подключаться к уже рабочей сессии в любой момент.
    SUBSYSTEM=="input", KERNEL=="event*", ATTRS{name}=="Sunshine (libvirtualhid) X-Box Series Controller", OWNER="root", GROUP="root", MODE="0000", TAG-="uaccess", RUN+="${pkgs.acl}/bin/setfacl -b $env{DEVNAME}"
    SUBSYSTEM=="input", KERNEL=="js*", ATTRS{name}=="Sunshine (libvirtualhid) X-Box Series Controller", OWNER="root", GROUP="root", MODE="0000", TAG-="uaccess", RUN+="${pkgs.acl}/bin/setfacl -b $env{DEVNAME}"
    SUBSYSTEM=="hidraw", ENV{HID_PHYS}=="libvirtualhid/uhid/*", OWNER="root", GROUP="root", MODE="0000", TAG-="uaccess", RUN+="${pkgs.acl}/bin/setfacl -b $env{DEVNAME}"
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
      csrf_allowed_origins = "https://169.58.98.9:47990";
      origin_web_ui_allowed = "wan";
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

  # NOPASSWD строго на game-power-tune. Скрипт принимает только start|stop
  # и пишет лишь в platform_profile, amdgpu DPM и vm.swappiness.
  security.sudo.extraRules = [
    {
      users = [ "valen" ];
      commands = [
        {
          command = "${gamePowerTune}/bin/game-power-tune";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
