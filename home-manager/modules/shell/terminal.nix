# Ghostty — терминал по умолчанию.
{ ... }:

{
  programs.ghostty = {
    enable = true;
    settings = {
      background-opacity = 0.7;
      window-decoration = true;
      font-family = "JetBrains Mono";
      font-size = 12;
      cursor-style = "bar";
      keybind = [
        "super+space=ignore"
        "ctrl+c=copy_to_clipboard"
        "ctrl+v=paste_from_clipboard"
        "ctrl+shift+c=text:\\x03"
      ];
    };
  };
}
