{ config, pkgs, ... }:

{
  # Yazi
  xdg.configFile."yazi/yazi.toml" = {
    text = ''
      [opener]
      edit = [
        { run = 'micro "$@"', block = true }
      ]
      
      [manager]
      show_hidden = true
      sort_by = "natural"
    '';
    force = true;
  };

  # Декларативный конфиг dgop
  xdg.configFile."dgop/color.json".source = ./assets/dgop-color.json;
}
