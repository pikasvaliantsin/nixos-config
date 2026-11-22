#!/usr/bin/env bash
# Тонкий бэкап проверенного RF4-префикса (без 42 ГиБ файлов игры).
#
#   bash scripts/backup-rf4-prefix.sh [куда.tar.gz]
#
# Сохраняет реестр, dosdevices, system32/syswow64 (включая portproton-редисты
# и шрифты) и профиль steamuser. Сами файлы игры не входят — их заново
# скачает rf4-install.
#
# Кладётся на Ventoy как rf4-prefix-thin-YYYYMMDD.tar.gz; установочный скрипт
# находит его сам и предлагает восстановить.
set -Eeuo pipefail

src="${RF4_PREFIX:-$HOME/Games/rf4}"
out="${1:-$HOME/rf4-prefix-thin-$(date +%Y%m%d).tar.gz}"

[[ -d "$src/drive_c" ]] || {
  echo "!! Нет префикса: $src/drive_c" >&2
  exit 1
}
[[ -e "$src/system.reg" ]] || {
  echo "!! Нет $src/system.reg — это не Wine-префикс" >&2
  exit 1
}

echo "Источник: $src"
echo "Архив:    $out"
tar -C "$src" --exclude='drive_c/games' -czf "$out" .
echo
ls -lh "$out"
echo "Файлов в архиве: $(tar -tzf "$out" | wc -l)"
echo
echo "Проверка ключевых путей:"
listing=$(tar -tzf "$out")
for path in system.reg user.reg dosdevices/c: drive_c/windows/system32 drive_c/users/steamuser; do
  if grep -qE "^\./${path%/}(/|$)" <<<"$listing"; then
    echo "  ok  $path"
  else
    echo "  !!  $path отсутствует"
  fi
done
