# Fastfetch: приветствие при старте интерактивного Fish.
{ ... }:

{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "small";
        padding = {
          top = 1;
          left = 2;
        };
      };
      display = {
        separator = "  ";
        key.width = 16;
      };
      modules = [
        "break"
        {
          type = "title";
          format = "  {user-name-colored}@{host-name-colored}";
        }
        {
          type = "custom";
          format = "  ┌──────────────────────────────────────────────────┐";
        }
        {
          type = "os";
          key = "  │ 󰍹 os";
          keyColor = "31";
        }
        {
          type = "kernel";
          key = "  │ 󰌽 kernel";
          keyColor = "32";
        }
        {
          type = "uptime";
          key = "  │ 󰅐 uptime";
          keyColor = "33";
        }
        {
          type = "wm";
          key = "  │ 󰨇 wm";
          keyColor = "34";
        }
        {
          type = "shell";
          key = "  │ 󰞷 shell";
          keyColor = "35";
        }
        {
          type = "cpu";
          key = "  │ 󰻠 cpu";
          keyColor = "31";
        }
        {
          type = "memory";
          key = "  │ 󰍛 memory";
          keyColor = "33";
          format = "{1} / {2} ({3})";
        }
        {
          type = "swap";
          key = "  │ 󰓡 swap";
          keyColor = "33";
          format = "{1} / {2} ({3})";
        }
        {
          type = "disk";
          key = "  │ 󰋊 root (/)";
          keyColor = "34";
          folders = "/";
        }
        {
          type = "disk";
          key = "  │ 󰋊 home";
          keyColor = "34";
          folders = "/home";
        }
        {
          type = "custom";
          format = "  └──────────────────────────────────────────────────┘";
        }
        "break"
        {
          type = "colors";
          paddingLeft = 2;
          symbol = "circle";
        }
        "break"
      ];
    };
  };
}
