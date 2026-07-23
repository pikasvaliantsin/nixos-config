{ config, pkgs, ... }:

{
  xdg.configFile."micro/settings.json" = {
    text = ''
      {
        "colorscheme": "solarized",
        "tabstospaces": true,
        "tabwidth": 2,
        "autosu": true,
        "ruler": true,
        "softwrap": true,
        "clipboard": "external"
      }
    '';
    force = true;
  };
}
