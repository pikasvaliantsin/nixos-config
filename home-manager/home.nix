{ config, pkgs, inputs, ... }:

{
  home.username = "valen";
  home.homeDirectory = "/home/valen";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # User packages
  home.packages = with pkgs; [
    micro
    vim
    yazi
    lsd
    alacritty
    kitty
    tree
    ripgrep
    fd
    bat
    jq
    unzip
    wget
    hyprpaper
    waybar
    wofi
    dunst
    grim
    slurp
    wl-clipboard
  ];

  # Fish Shell
  programs.fish = {
    enable = true;
    shellInit = ''
      set -gx EDITOR micro
      set -gx VISUAL micro
      set -gx XDG_CURRENT_DESKTOP Hyprland
      set -gx XDG_SESSION_TYPE wayland
      set -g fish_greeting ""
      set -g __fish_git_prompt_show_informative_status 1
    '';
    shellAliases = {
      ls = "lsd";
      ll = "ls -l";
      la = "ls -a";
      tree = "lsd --tree";
      edit = "micro";
      cat = "bat";
      grep = "ripgrep";
      update = "sudo nixos-rebuild switch --flake ~/nixos-config#desktop";
    };
  };

  # Git
  programs.git = {
    enable = true;
    userName = "Valentin Pikas";
    userEmail = "pikasvaliantsin@github.com";
    extraConfig = {
      core.editor = "micro";
      init.defaultBranch = "main";
      color.ui = true;
      alias = {
        co = "checkout";
        br = "branch";
        ci = "commit";
        st = "status";
        lg = "log --oneline --graph --all";
      };
    };
  };

  # Yazi
  xdg.configFile."yazi/yazi.toml".text = ''
    [opener]
    edit = [
      { run = 'micro "$@"', block = true }
    ]
    
    [manager]
    show_hidden = true
    sort_by = "natural"
  '';

  # Alacritty
  xdg.configFile."alacritty/alacritty.toml".text = ''
    [window]
    opacity = 0.9
    decorations = "full"
    
    [font]
    size = 12
    
    [font.normal]
    family = "JetBrains Mono"
    
    [colors]
    primary = { background = "#1e1e2e", foreground = "#cdd6f4" }
    normal = { black = "#45475a", red = "#f38ba8", green = "#a6e3a1", yellow = "#f9e2af" }
  '';

  # Hyprland
  xdg.configFile."hypr/hyprland.conf".text = ''
    # Monitor
    monitor=,preferred,auto,auto
    
    # Exec once
    exec-once = waybar
    exec-once = dunst
    
    # Input
    input {
      kb_layout = us
      follow_mouse = 1
      natural_scroll = no
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
    
    # Gestures
    gestures {
      workspace_swipe = true
      workspace_swipe_fingers = 3
    }
    
    # Keybindings
    bind = SUPER, Q, exec, alacritty
    bind = SUPER, E, exec, yazi
    bind = SUPER, R, exec, wofi --show drun
    bind = SUPER, SPACE, exec, wofi --show drun
    bind = SUPER, F, fullscreen
    bind = SUPER, V, togglefloating
    bind = SUPER, H, movefocus, l
    bind = SUPER, L, movefocus, r
    bind = SUPER, K, movefocus, u
    bind = SUPER, J, movefocus, d
    
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
    
    # Screenshots
    bind = SUPER, S, exec, grim -g "$(slurp)" ~/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png
  '';
}
