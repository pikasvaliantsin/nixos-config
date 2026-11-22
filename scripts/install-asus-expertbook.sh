#!/usr/bin/env bash
# Установка ASUS ExpertBook с live-ISO NixOS.
#
#   sudo bash scripts/install-asus-expertbook.sh
#
# Что делает:
#   1. Проверяет, что это live-ISO, UEFI, есть сеть и что /dev/nvme0n1 —
#      действительно Samsung PM9A1.
#   2. Показывает SATA /dev/sda и НЕ трогает его.
#   3. Требует подтверждение словом ERASE.
#   4. Клонирует ветку desktop/omarchy-shell и проверяет, что disko в ней
#      описывает только NVMe.
#   5. Запускает закреплённый в flake.lock disko (только NVMe).
#   6. Кладёт sops host key в /mnt/etc/ssh, если находит его рядом со скриптом.
#   7. Выполняет nixos-install --flake .#asus-expertbook.
#   8. Предлагает восстановить тонкий бэкап RF4-префикса с флешки.
#
# Переменные окружения:
#   SOPS_KEY=/path/ssh_host_ed25519_key   — явный путь к ключу
#   RF4_BACKUP=/path/rf4-prefix-thin.tar.gz — явный путь к бэкапу префикса
set -Eeuo pipefail

BRANCH="desktop/omarchy-shell"
REPO_URL="https://github.com/pikasvaliantsin/nixos-config.git"
CONFIG="asus-expertbook"
DISKO_REV="1dd30c29c88d99ce295f15e27f93c49bc5fbae07"
TARGET_DISK="/dev/nvme0n1"
EXPECTED_MODEL="MZVL2512HCJQ"
REPO_DIR="/root/nixos-config"
LOG="/tmp/install-${CONFIG}.log"
NIX=(nix --extra-experimental-features "nix-command flakes")

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
warn() { printf '\n\033[1;33m!! %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }
trap 'echo "!! Ошибка на строке $LINENO" >&2' ERR

exec > >(tee -a "$LOG") 2>&1

[[ $EUID -eq 0 ]] || die "запустите через sudo: sudo bash $0"
[[ ! -e /etc/NIXOS ]] || die "это установленная система, а не live-ISO"
command -v nixos-install >/dev/null || die "nixos-install не найден — это не образ установщика NixOS"
[[ -d /sys/firmware/efi ]] || die "загрузитесь в UEFI-режиме (сейчас нет /sys/firmware/efi)"

say "Проверка диска $TARGET_DISK"
[[ -b "$TARGET_DISK" ]] || die "$TARGET_DISK не найден"
model=$(lsblk -dno MODEL "$TARGET_DISK" | xargs)
[[ $model == *"$EXPECTED_MODEL"* ]] || die "на $TARGET_DISK модель '$model', ожидалась $EXPECTED_MODEL"
if lsblk -nro MOUNTPOINT "$TARGET_DISK" | grep -q .; then
  die "на $TARGET_DISK есть смонтированные разделы — отмонтируйте их"
fi

say "Сеть"
curl -fsSI --max-time 15 https://cache.nixos.org >/dev/null \
  || die "нет доступа к cache.nixos.org — проверьте Wi-Fi/Ethernet (nmtui)"

say "Что будет стёрто"
lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL "$TARGET_DISK"
if [[ -b /dev/sda ]]; then
  warn "SATA /dev/sda НЕ ТРОГАЕМ (disko его не описывает):"
  lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL /dev/sda
fi
echo
echo "На $TARGET_DISK будут уничтожены все разделы, включая текущие"
echo "CachyOS и тестовую NixOS. Отменить это будет нельзя."
read -rp "Введите ERASE, чтобы продолжить: " answer
[[ $answer == "ERASE" ]] || die "отменено"

say "Клонирование ветки $BRANCH"
rm -rf "$REPO_DIR"
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR" \
  || die "не удалось склонировать $REPO_URL"
cd "$REPO_DIR"
echo "Коммит: $(git log --oneline -1)"

say "Проверка disko-конфига"
expr="builtins.map (d: d.device) (builtins.attrValues (builtins.getFlake (toString ./.)).nixosConfigurations.${CONFIG}.config.disko.devices.disk)"
devices=$("${NIX[@]}" eval --impure --json --expr "$expr") \
  || die "не удалось вычислить disko-конфиг"
echo "disko управляет: $devices"
[[ $devices == *"\"$TARGET_DISK\""* ]] || die "в конфиге нет $TARGET_DISK"
[[ $devices != *"/dev/sda"* ]] || die "в конфиге всё ещё есть /dev/sda — установка отменена"

say "disko: destroy,format,mount ($TARGET_DISK)"
"${NIX[@]}" run "github:nix-community/disko/$DISKO_REV" -- \
  --mode destroy,format,mount --flake ".#$CONFIG"
findmnt -n /mnt >/dev/null || die "disko не смонтировал корень в /mnt"

say "sops host key"
key=""
shopt -s nullglob
for candidate in \
  "${SOPS_KEY:-}" \
  "$(cd "$(dirname "$0")" && pwd)/ssh_host_ed25519_key" \
  /root/keys/ssh_host_ed25519_key \
  /run/media/*/*/ssh_host_ed25519_key \
  /mnt/*/ssh_host_ed25519_key
do
  if [[ -n $candidate && -f $candidate ]]; then key=$candidate; break; fi
done
shopt -u nullglob

if [[ -n $key ]]; then
  ssh-keygen -y -f "$key" >/dev/null 2>&1 || die "ключ $key не читается"
  install -d -m700 /mnt/etc/ssh
  install -m600 "$key" /mnt/etc/ssh/ssh_host_ed25519_key
  ssh-keygen -y -f "$key" > /mnt/etc/ssh/ssh_host_ed25519_key.pub
  chmod 644 /mnt/etc/ssh/ssh_host_ed25519_key.pub
  echo "Ключ установлен из $key"
else
  warn "ssh_host_ed25519_key не найден."
  echo "Без него sops не расшифрует секреты (включая пароль valen)."
  echo "Положите ключ рядом со скриптом, в /root/keys/ или на флешку,"
  echo "либо задайте SOPS_KEY=/путь/к/ключу."
  read -rp "Всё равно продолжить без ключа? [y/N]: " skip
  [[ $skip == [yY]* ]] || die "остановлено — добавьте ключ и запустите снова"
fi

say "nixos-install --flake .#$CONFIG"
NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-install --flake ".#$CONFIG"

say "Тонкий бэкап RF4-префикса (необязательно)"
backup=""
shopt -s nullglob
for candidate in \
  "${RF4_BACKUP:-}" \
  /run/media/*/*/rf4-prefix-thin-*.tar.gz \
  /mnt/*/rf4-prefix-thin-*.tar.gz
do
  if [[ -n $candidate && -f $candidate ]]; then backup=$candidate; break; fi
done
shopt -u nullglob

if [[ -n $backup ]]; then
  read -rp "Восстановить префикс из $(basename "$backup")? [Y/n]: " restore
  if [[ $restore != [nN]* ]]; then
    mkdir -p /mnt/home/valen/Games/rf4
    tar -xzf "$backup" -C /mnt/home/valen/Games/rf4
    ln -sfn . /mnt/home/valen/Games/rf4/pfx
    chown -R 1000:100 /mnt/home/valen/Games
    echo "Префикс восстановлен (без файлов игры, их скачает rf4-install)."
  fi
else
  echo "Бэкап rf4-prefix-thin-*.tar.gz не найден — пропускаю."
fi

say "Готово"
cat <<'EOF'
После перезагрузки:
  1. Войти как valen (пароль из sops).
  2. Проверить секреты:
       ls -l /run/secrets-for-users/valen_password
       systemctl status sops-nix
  3. Проверить загрузчик: efibootmgr -v (запись NixOS должна смотреть на NVMe).
  4. Игру ставить/докачивать: rf4-install, затем rf4-gamescope (в этой ветке
     ещё нет rf4-gs) или rf4.
  5. SATA /dev/sda остался нетронутым — его можно использовать как есть.
EOF

read -rp "Перезагрузиться сейчас? [y/N]: " reboot_now
if [[ $reboot_now == [yY]* ]]; then
  umount -R /mnt || true
  reboot
fi
