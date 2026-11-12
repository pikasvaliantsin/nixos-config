{ pkgs, ... }:

{
  programs.fish.enable = true;

  users.users.valen = {
    isNormalUser = true;
    # neededForUsers-секреты sops-nix кладёт в /run/secrets-for-users
    hashedPasswordFile = "/run/secrets-for-users/valen_password";
    extraGroups = [
      "wheel"
      "video"
      "audio"
      "input"
      "render"
      "networkmanager"
      "lp"
      "scanner"
      # Нужна GameMode для renice игровых процессов (CAP_SYS_NICE)
      "gamemode"
    ];
    shell = pkgs.fish;
  };

  # Пустой hashedPasswordFile означает вход без пароля. Не даём активации
  # пройти, если sops установил пустой секрет (например, до первого заполнения).
  system.activationScripts.checkValenPassword = ''
    if [ -e /run/secrets-for-users/valen_password ] && [ ! -s /run/secrets-for-users/valen_password ]; then
      echo "valen_password пуст: задай хеш в secrets/secrets.yaml перед rebuild" >&2
      exit 1
    fi
  '';
}
