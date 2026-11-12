# Кэш собственных сборок на VPS (Harmonia, доступен только через WireGuard).
#
# Nix сначала спрашивает кэш и только потом собирает. Ночью текущая система
# заливается на сервер, чтобы её содержимое пережило nix-collect-garbage,
# переустановку и появилось на второй машине без пересборки.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cacheUrl = "http://10.0.0.1:5000";
  # Публичный ключ подписи кэша (приватный — в sops на сервере).
  cacheKey = "vps-cache-1:vz3pjhPwHhXmXdfL7KrAh5RzeamtXHibYrmi4xVg/KU=";
  cacheHost = "root@169.58.98.9";

  pushScript = pkgs.writeShellScript "nix-cache-push" ''
    set -eu

    # Без поднятого туннеля кэш недоступен: это не повод для failed-юнита.
    if ! ${pkgs.iproute2}/bin/ip -4 route get 10.0.0.1 >/dev/null 2>&1; then
      echo "wg0 недоступен, пропускаю заливку"
      exit 0
    fi

    tmp=$(${pkgs.coreutils}/bin/mktemp -d)
    trap '${pkgs.coreutils}/bin/rm -rf "$tmp"' EXIT

    ${pkgs.nix}/bin/nix-store -qR /run/current-system > "$tmp/closure.txt"
    ${pkgs.nix}/bin/nix path-info --json-format 1 --json \
      $(cat "$tmp/closure.txt") > "$tmp/info.json"

    # Подписано cache.nixos.org → это публичное, сервер скачает сам.
    ${pkgs.jq}/bin/jq -r '
      to_entries[]
      | select(.value.signatures | any(startswith("cache.nixos.org-1:")))
      | .key' "$tmp/info.json" > "$tmp/public.txt"

    # Всё остальное — наши сборки (zen, openide, dux, ayugram...) и чужие
    # cachix-пакеты. Только это и уезжает с ноута.
    ${pkgs.jq}/bin/jq -r '
      to_entries[]
      | select(.value.signatures | any(startswith("cache.nixos.org-1:")) | not)
      | .key' "$tmp/info.json" > "$tmp/local.txt"

    echo "публичных путей: $(wc -l < "$tmp/public.txt"), своих: $(wc -l < "$tmp/local.txt")"

    if [ -s "$tmp/public.txt" ]; then
      ${pkgs.openssh}/bin/ssh -o BatchMode=yes root@169.58.98.9 \
        "xargs -a /dev/stdin -P 8 -n 64 ${pkgs.nix}/bin/nix copy \
           --from https://cache.nixos.org" < "$tmp/public.txt" || true
    fi

    if [ -s "$tmp/local.txt" ]; then
      ${pkgs.nix}/bin/nix copy \
        --to "ssh-ng://${cacheHost}" \
        --no-check-sigs \
        $(cat "$tmp/local.txt")
    fi
  '';
in
{
  nix.settings = {
    substituters = [ cacheUrl ];
    trusted-public-keys = [ cacheKey ];
  };

  systemd.services.nix-cache-push = {
    description = "Залить текущую систему в Nix-кэш на VPS";
    path = [
      pkgs.nix
      pkgs.openssh
      pkgs.iproute2
      pkgs.coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "valen";
      Environment = [ "HOME=/home/valen" ];
      ExecStart = pushScript;
      # Не мешать интерактивной работе: заливка идёт в фоне с низким приоритетом.
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers.nix-cache-push = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00";
      RandomizedDelaySec = "45min";
      Persistent = true;
    };
  };
}
