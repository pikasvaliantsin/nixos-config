# Разметка основного диска — NVMe.
#
# Samsung PM9A1 (MZVL2512HCJQ-00B00) имеет дефект ухода в D3/низкое
# потребление, поэтому платформа живёт с полным запретом сна
# (system/sleep-policy.nix), а не с обходом питания диска.
#
# /dev/sda (медленный SATA SSD) намеренно НЕ описан: disko его не трогает.
# Диск остаётся как есть — под эксперименты с другими ОС и некритичные данные.
{
  disko.devices = {
    disk = {
      system = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            swap = {
              size = "8G";
              # Hibernation запрещён sleep-policy.nix, поэтому resumeDevice
              # не задаём: swap нужен только как резерв для zram.
              content = {
                type = "swap";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = [
                      "compress=zstd:1" # Лёгкая компрессия для системных файлов
                      "noatime" # Отключаем запись времени доступа
                      "space_cache=v2" # Оптимизация метаданных Btrfs
                    ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress=zstd:1"
                      "noatime"
                      "space_cache=v2"
                    ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "compress=no" # Логи не сжимаем — важна скорость записи
                      "noatime"
                      "space_cache=v2"
                    ];
                  };
                  # /home теперь на том же NVMe: отдельный сабтом сохраняет
                  # прежние mount-опции и возможность снапшотов.
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=no" # Без компрессии — важна скорость записи при загрузке игр
                      "noatime"
                      "space_cache=v2"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
