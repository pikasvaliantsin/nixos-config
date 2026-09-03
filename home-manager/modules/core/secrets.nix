# nixos-config/home-manager/modules/core/secrets.nix
#
# ────────────────────────────────────────────────────────────────────────────
# РАЗВЁРТЫВАНИЕ СЕКРЕТОВ НА НОВОЙ МАШИНЕ
# ────────────────────────────────────────────────────────────────────────────
#
# Как работает расшифровка secrets/secrets.yaml:
#
#   Файл secrets/secrets.yaml зашифрован age-ключом, который был сгенерирован
#   из публичного SSH-ключа текущего хоста (/etc/ssh/ssh_host_ed25519_key.pub).
#   sops-nix при rebuild:
#     1. Берёт приватный SSH-ключ из /etc/ssh/ssh_host_ed25519_key
#     2. Конвертирует его в age private key (на лету)
#     3. Расшифровывает secrets/secrets.yaml в /run/secrets/<secret_name>
#     4. activation-скрипт ниже копирует ключ в ~/.ssh/id_ed25519
#
#   ПРОБЛЕМА: На абсолютно новой машине приватный хостовый ключ
#   /etc/ssh/ssh_host_ed25519_key будет другим, поэтому sops НЕ СМОЖЕТ
#   расшифровать секреты "из коробки".
#
# ── Два стандартных решения: ────────────────────────────────────────────────
#
#   ВАРИАНТ А (Основной): Перенос хостового SSH-ключа
#   ──────────────────────────────────────────────────────────────────────────
#
#   Перед переустановкой сохрани приватный ключ хоста в бекап:
#
#     scp /etc/ssh/ssh_host_ed25519_key     user@backup:~/backup/
#     scp /etc/ssh/ssh_host_ed25519_key.pub user@backup:~/backup/
#
#   После установки новой системы восстанови ключи ДО первого nixos-rebuild:
#
#     sudo cp ~/backup/ssh_host_ed25519_key     /etc/ssh/
#     sudo cp ~/backup/ssh_host_ed25519_key.pub /etc/ssh/
#     sudo chmod 600 /etc/ssh/ssh_host_ed25519_key
#     sudo chown root:root /etc/ssh/ssh_host_ed25519_key
#
#   Теперь sops-nix сможет расшифровать секреты тем же ключом.
#
#   ВАРИАНТ Б (Личный age-ключ): Добавление второго master key
#   ──────────────────────────────────────────────────────────────────────────
#
#   Создай личный age-ключ (YubiKey, смартфон, домашний ПК) и добавь его
#   публичную часть в .sops.yaml ВМЕСТЕ с хостовым ключом, разделив запятой:
#
#     age: age1xxx(host),age1xxx(personal)
#
#   Генерация личного age-ключа:
#
#     nix shell nixpkgs#age -c age-keygen -o ~/.config/sops/age/keys.txt
#     cat ~/.config/sops/age/keys.txt   # покажет публичный key: age1...
#
#   Расшифровка через личный ключ:
#
#     SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/secrets.yaml
#
#   Это позволяет работать с секретами с любой машины, даже если хостовый
#   SSH-ключ отличается.
# ────────────────────────────────────────────────────────────────────────────
#
{ config, ... }:

{
  home.activation.installGithubSshKey = {
    after = [ "writeBoundary" ];
    before = [ ];
    data = ''
      if [ -f /run/secrets/github_ssh_key ]; then
        mkdir -p ${config.home.homeDirectory}/.ssh
        cp /run/secrets/github_ssh_key ${config.home.homeDirectory}/.ssh/id_ed25519
        chmod 600 ${config.home.homeDirectory}/.ssh/id_ed25519
      fi
    '';
  };
}
