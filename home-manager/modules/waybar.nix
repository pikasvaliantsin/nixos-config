{ config, pkgs, ... }:

{
  xdg.configFile."waybar/config" = {
    text = ''
      {
        "layer": "top",
        "position": "top",
        "height": 30,
        "modules-left": ["hyprland/workspaces"],
        "modules-center": ["hyprland/window"],
        "modules-right": ["clock", "cpu", "memory", "disk"]
      }
    '';
    force = true;
  };
}
