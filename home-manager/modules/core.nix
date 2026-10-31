# Общие параметры пользовательской среды.
{
  config,
  lib,
  ...
}:

{
  options.mySystem.dotfilesRoot = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/nixos-config";
    description = ''
      Путь к checkout'у nixos-config. Out-of-store симлинки для niri/DMS
      указывают сюда, поэтому альтернативные checkout'ы (git worktree) могут
      использовать собственные живые конфиги, не затрагивая основной.
    '';
  };

  config = {
    home.username = "valen";
    home.homeDirectory = "/home/valen";
    home.stateVersion = "26.11";
    home.enableNixpkgsReleaseCheck = false;

    programs.home-manager.enable = true;
  };
}
