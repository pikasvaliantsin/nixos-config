# Импорт-хаб пользовательской оболочки.
# Каждый компонент лежит в отдельном файле, чтобы не раздувать один модуль.
_:

{
  imports = [
    ./shell/cli.nix
    ./shell/fish.nix
    ./shell/git.nix
    ./shell/starship.nix
    ./shell/terminal.nix
    ./shell/fastfetch.nix
  ];
}
