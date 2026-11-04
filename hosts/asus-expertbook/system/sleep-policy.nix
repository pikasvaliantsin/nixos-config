# Полный запрет сна на этой платформе.
#
# Samsung PM9A1 (MZVL2512HCJQ-00B00) не выходит из D3/низкого потребления:
# s2idle/Modern Standby вешает ноутбук намертво. Обход D3 (noacpi, APST,
# d3cold_allowed=0) проблему не устранил, поэтому вместо сна — выключение.
#
# Что делает модуль:
#   1. systemd вообще не разрешает suspend/hibernate/hybrid-sleep.
#   2. Юниты сна маскируются, чтобы их нельзя было запустить даже вручную.
#   3. Закрытие крышки выключает ноутбук (в док-станции — игнорируется).
#   4. Кнопки suspend/hibernate и idle-действия игнорируются.
{ ... }:

{
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # Маскируем и цели, и сервисы сна — на случай, если что-то попытается
  # запустить их напрямую.
  systemd.suppressedSystemUnits = [
    "sleep.target"
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
    "systemd-suspend.service"
    "systemd-hibernate.service"
    "systemd-hybrid-sleep.service"
    "systemd-suspend-then-hibernate.service"
  ];

  services.logind.settings.Login = {
    # Крышка: выключение, а не сон.
    HandleLidSwitch = "poweroff";
    HandleLidSwitchExternalPower = "poweroff";
    # В док-станции крышку игнорируем, чтобы не выключить рабочий стол.
    HandleLidSwitchDocked = "ignore";

    # Случайные нажатия клавиш сна ничего не делают.
    HandleSuspendKey = "ignore";
    HandleHibernateKey = "ignore";

    # Никакого автоматического сна по простою.
    IdleAction = "ignore";
  };
}
