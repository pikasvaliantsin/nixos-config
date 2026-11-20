# Локальные контейнерные сервисы (rf4_server_simulator и подобные).
#
# Docker, а не rootless Podman: compose-файл проекта использует
# depends_on.condition=service_completed_successfully и healthcheck'и,
# которые надёжно обрабатывает docker compose v2. Порты наружу при этом
# не открываются — контейнеры публикуют их только на 127.0.0.1
# (RF4_BIND_IP в .env, дефолт в compose тоже loopback).
{ pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    # Демон стартует при загрузке; контейнеры поднимаются вручную/через compose.
    enableOnBoot = true;
  };

  environment.systemPackages = with pkgs; [
    # compose v2: `docker-compose up -d --build --wait`
    docker-compose
  ];

  # Группа docker даёт доступ к root-демону, но у valen уже есть wheel
  # и sudo, так что новых привилегий это не добавляет.
  users.users.valen.extraGroups = [ "docker" ];
}
