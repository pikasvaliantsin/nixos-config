_:

{
  time.timeZone = "Europe/Minsk";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "ru_RU.UTF-8/UTF-8"
    ];

    extraLocaleSettings = {
      LC_TIME = "ru_RU.UTF-8";
      LC_MONETARY = "ru_RU.UTF-8";
      LC_ADDRESS = "ru_RU.UTF-8";
      LC_TELEPHONE = "ru_RU.UTF-8";
      LC_MEASUREMENT = "ru_RU.UTF-8";
      LC_IDENTIFICATION = "ru_RU.UTF-8";
    };
  };

  console = {
    font = "cyr-sun16";
    # В голом TTY нет XKB-групп: Super+Space там не работает. Этот keymap
    # даёт Windows-подобное переключение RU/EN по Alt+Shift прямо в консоли
    # (UTF-8, чтобы кириллица совпадала с локалью).
    keyMap = "ruwin_alt_sh-UTF-8";
  };
}
