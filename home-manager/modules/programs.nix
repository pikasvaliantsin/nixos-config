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
}
