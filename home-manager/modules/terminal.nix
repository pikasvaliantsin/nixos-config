{ config, pkgs, ... }:

{
  xdg.configFile."alacritty/alacritty.toml".text = ''
    [window]
    opacity = 0.95
    decorations = "full"
    padding = { x = 10, y = 10 }
    dynamic_padding = true
    
    [font]
    size = 12
    
    [font.normal]
    family = "JetBrains Mono"
    style = "Regular"
    
    [font.bold]
    family = "JetBrains Mono"
    style = "Bold"
    
    [font.italic]
    family = "JetBrains Mono"
    style = "Italic"
    
    [colors]
    primary = { background = "#1e1e2e", foreground = "#cdd6f4" }
    normal = { black = "#45475a", red = "#f38ba8", green = "#a6e3a1", yellow = "#f9e2af", blue = "#89b4fa", magenta = "#cba6f7", cyan = "#94e2d5", white = "#bac2de" }
    bright = { black = "#585b70", red = "#f38ba8", green = "#a6e3a1", yellow = "#f9e2af", blue = "#89b4fa", magenta = "#cba6f7", cyan = "#94e2d5", white = "#a6adc8" }
    
    [cursor]
    style = "Beam"
    unfocused_hollow = false
  '';
}
