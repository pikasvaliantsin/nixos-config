{ config, pkgs, ... }:

let
  # Определяем путь к jetbrains-toolbox (unstable)
  toolbox = pkgs.jetbrains-toolbox;
in
{
  # 1. Принудительно переопределяем .desktop файл
  xdg.dataFile."applications/jetbrainsd.desktop".text = ''
    [Desktop Entry]
    Version=1.5
    Name=JetBrains
    Type=Application
    NoDisplay=true
    MimeType=x-scheme-handler/jetbrains;
    Exec=${toolbox}/bin/jetbrains-toolbox %u
  '';

  # 2. Регистрируем MIME-тип для этого файла
  xdg.mime.defaultApplications = {
    "x-scheme-handler/jetbrains" = "jetbrainsd.desktop";
  };

  # 3. (Опционально) Гарантируем, что Toolbox всегда установлен через unstable
  home.packages = [ toolbox ];
}
