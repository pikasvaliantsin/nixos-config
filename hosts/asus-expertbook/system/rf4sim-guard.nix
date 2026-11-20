# Сетевая изоляция локального клиента RF4 (rf4_server_simulator).
#
# Локальный клиент запускается в cgroup rf4sim.slice (см. home-manager
# rf4.nix, команда rf4sim). Для сокетов этой cgroup:
#   * TCP 443/9341/7515 принудительно редиректятся на 127.0.0.1: те же
#     порты, где слушает docker-стек симулятора. Клиент физически не может
#     открыть соединение с официальным сервером, даже если DNS вернул его IP:
#     пакет не покидает хост.
#   * всё остальное вне loopback дропается, включая UDP/ICMP/QUIC.
# Официальный клиент (rf4) работает в другой cgroup, правил не касается.
#
# Почему не hosts в префиксе: Wine резолвит имена через glibc хоста
# (/etc/hosts, systemd-resolved), файл внутри drive_c игнорируется.
{ pkgs, ... }:

let
  # 4 компонента от корня cgroup v2: user.slice / user-1000.slice /
  # user@1000.service / rf4sim.slice
  slice = "user.slice/user-1000.slice/user@1000.service/rf4sim.slice";

  rules = pkgs.writeText "rf4sim-guard.nft" ''
    table inet rf4simguard {
      chain out_redirect {
        type nat hook output priority -100; policy accept;
        socket cgroupv2 level 4 "${slice}" tcp dport 443 redirect to :443
        socket cgroupv2 level 4 "${slice}" tcp dport 9341 redirect to :9341
        socket cgroupv2 level 4 "${slice}" tcp dport 7515 redirect to :7515
      }

      chain out_filter {
        type filter hook output priority 0; policy accept;
        socket cgroupv2 level 4 "${slice}" ip daddr != 127.0.0.0/8 drop
        socket cgroupv2 level 4 "${slice}" ip6 daddr != ::1 drop
      }
    }
  '';
in
{
  systemd.services.rf4sim-netguard = {
    description = "nftables egress guard for the local RF4 client slice";
    wantedBy = [ "multi-user.target" ];
    after = [
      "firewall.service"
      "docker.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      # Идемпотентно: своя таблица, чужие правила не трогаем.
      ${pkgs.nftables}/bin/nft delete table inet rf4simguard 2>/dev/null || true
      ${pkgs.nftables}/bin/nft -f ${rules}
    '';
  };
}
