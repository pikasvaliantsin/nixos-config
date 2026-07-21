{ config, pkgs, ... }:

{
  # Настройка micro
  xdg.configFile."micro/settings.json".text = ''
    {
      "colorscheme": "solarized",
      "tabstospaces": true,
      "tabwidth": 2,
      "autosu": true,
      "ruler": true,
      "softwrap": true
    }
  '';
}
