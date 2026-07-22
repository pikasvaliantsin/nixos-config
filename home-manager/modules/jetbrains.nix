{ config, pkgs, ... }:

let
  toolbox = pkgs.jetbrains-toolbox;
in
{
  xdg.dataFile."applications/jetbrainsd.desktop" = {
    text = ''
      [Desktop Entry]
      Version=1.5
      Name=JetBrains
      Type=Application
      NoDisplay=true
      MimeType=x-scheme-handler/jetbrains;
      Exec=${toolbox}/bin/jetbrains-toolbox %u
    '';
    force = true;  # <-- добавляем
  };

  # Если используем mimeApps, оставляем как есть
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/jetbrains" = "jetbrainsd.desktop";
  };
}
