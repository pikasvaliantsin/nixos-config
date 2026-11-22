# Тестовая установка рядом с CachyOS.
#
# Форматируются ТОЛЬКО разделы с метками RF4TEST-* (198 ГиБ + 1 ГиБ ESP),
# созданные заранее на nvme0n1. sda (CachyOS), nvme0n1p1 (swap) и
# nvme0n1p2 (/home CachyOS) не затрагиваются.
{
  disko.devices = {
    disk.root = {
      device = "/dev/disk/by-partlabel/RF4TEST-ROOT";
      type = "disk";
      content = {
        type = "btrfs";
        extraArgs = [ "-f" ];
        subvolumes = {
          "@" = {
            mountpoint = "/";
            mountOptions = [ "compress=zstd:1" "noatime" "space_cache=v2" ];
          };
          "@home" = {
            mountpoint = "/home";
            mountOptions = [ "compress=no" "noatime" "space_cache=v2" ];
          };
          "@nix" = {
            mountpoint = "/nix";
            mountOptions = [ "compress=zstd:1" "noatime" "space_cache=v2" ];
          };
          "@log" = {
            mountpoint = "/var/log";
            mountOptions = [ "compress=no" "noatime" "space_cache=v2" ];
          };
        };
      };
    };

    disk.esp = {
      device = "/dev/disk/by-partlabel/RF4TEST-ESP";
      type = "disk";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = [ "umask=0077" ];
      };
    };
  };
}
