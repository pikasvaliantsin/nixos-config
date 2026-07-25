{ pkgs, config, ... }:
{
  # ==========================================
  # Конфигурация wlogout (Меню питания)
  # ==========================================
  xdg.configFile."wlogout/layout".text = ''
    {
      "label" : "lock",
      "action" : "swaylock -f -c 000000",
      "text" : "Lock",
      "keybind" : "l"
    }
    {
      "label" : "hibernate",
      "action" : "systemctl hibernate",
      "text" : "Hibernate",
      "keybind" : "h"
    }
    {
      "label" : "logout",
      "action" : "loginctl terminate-user $USER",
      "text" : "Logout",
      "keybind" : "e"
    }
    {
      "label" : "shutdown",
      "action" : "systemctl poweroff",
      "text" : "Shutdown",
      "keybind" : "s"
    }
    {
      "label" : "reboot",
      "action" : "systemctl reboot",
      "text" : "Reboot",
      "keybind" : "r"
    }
  '';

  xdg.configFile."wlogout/style.css".text = ''
    * {
      font-family: "JetBrains Mono", FontAwesome, sans-serif;
      font-size: 14px;
    }
    window {
      background-color: rgba(30, 30, 46, 0.9); /* Catppuccin Mocha / Dracula dark */
    }
    button {
      color: #f8f8f2;
      background-color: #282a36;
      border: 2px solid #bd93f9; /* Dracula purple */
      border-radius: 12px;
      margin: 10px;
    }
    button:hover {
      background-color: #bd93f9;
      color: #282a36;
    }
  '';
}
