{ config, pkgs, ... }:

{
  xdg.configFile."hypr/hyprland.conf".text = ''
    # Monitor
    monitor=HDMI-A-1, 3440x1440@50, 0x0, 1
    monitor=eDP-1, 1920x1080@60, 3440x0, 1

    # Exec once
    exec-once = waybar &
    exec-once = dunst &

    # Input
    input {
      kb_layout = us,ru
      kb_options = grp:win_space_toggle
      follow_mouse = 0
      sensitivity = 0
      touchpad {
        natural_scroll = false
      }
    }

    # General
    general {
      gaps_in = 5
      gaps_out = 10
      border_size = 2
      col.active_border = rgba(89b4faff)
      col.inactive_border = rgba(313244ff)
    }

    # Decoration
    decoration {
      rounding = 5
      blur {
        enabled = true
        size = 5
        passes = 2
      }
    }

    # Keybindings
    bind = SUPER, RETURN, exec, alacritty
    bind = SUPER, Q, killactive,
    bind = SUPER, E, exec, yazi
    bind = SUPER, R, exec, wofi --show drun
    bind = SUPER, B, exec, firefox
    bind = SUPER, G, exec, google-chrome-stable
    bind = SUPER, F, fullscreen
    bind = SUPER, T, togglefloating

    # Screenshots (hyprshot)
    bind = SUPER, S, exec, hyprshot -m region
    bind = SUPER SHIFT, S, exec, hyprshot -m window
    bind = SUPER CTRL, S, exec, hyprshot -m output

    # Navigation (VIM style + arrows)
    bind = SUPER, H, movefocus, l
    bind = SUPER, L, movefocus, r
    bind = SUPER, K, movefocus, u
    bind = SUPER, J, movefocus, d
    bind = SUPER, left, movefocus, l
    bind = SUPER, right, movefocus, r
    bind = SUPER, up, movefocus, u
    bind = SUPER, down, movefocus, d

    # Move windows
    bind = SUPER SHIFT, left, movewindow, l
    bind = SUPER SHIFT, right, movewindow, r
    bind = SUPER SHIFT, up, movewindow, u
    bind = SUPER SHIFT, down, movewindow, d

    # Workspaces
    bind = SUPER, 1, workspace, 1
    bind = SUPER, 2, workspace, 2
    bind = SUPER, 3, workspace, 3
    bind = SUPER, 4, workspace, 4
    bind = SUPER, 5, workspace, 5

    bind = SUPER SHIFT, 1, movetoworkspace, 1
    bind = SUPER SHIFT, 2, movetoworkspace, 2
    bind = SUPER SHIFT, 3, movetoworkspace, 3
    bind = SUPER SHIFT, 4, movetoworkspace, 4
    bind = SUPER SHIFT, 5, movetoworkspace, 5

    # Media keys
    bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
    bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

    # Brightness
    bind = , XF86MonBrightnessUp, exec, brightnessctl s +10%
    bind = , XF86MonBrightnessDown, exec, brightnessctl s 10%-
  '';
}
