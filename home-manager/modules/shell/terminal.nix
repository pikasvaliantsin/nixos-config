# Ghostty — терминал по умолчанию.
_:

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
        # ctrl+v намеренно не биндим: его должен получать TUI (OpenCode
        # умеет читать картинку из буфера). Текст вставляется по ctrl+shift+v.
        "ctrl+shift+c=text:\\x03"
      ];
    };
  };
}
