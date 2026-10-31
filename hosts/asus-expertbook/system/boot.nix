{ pkgs, ... }:

{
  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    loader.efi.canTouchEfiVariables = true;
    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [
      "amd_pstate=active"
      "iommu=pt"
    ];

    kernel.sysctl = {
      # Агрессивный сброс страниц в zRAM
      "vm.swappiness" = 180;

      # КРИТИЧНО ДЛЯ zRAM: отключает чтение страниц блоками (кластерами).
      # Для дисков нужна упреждающая вычитка, для RAM latency равна 0 — читаем строго по 4 КБ.
      "vm.page-cluster" = 0;

      # Борьба со статтерами и пиками задержек (актуально для игр и тяжелых билдов)
      "vm.watermark_boost_factor" = 0;
      "vm.watermark_scale_factor" = 125;

      # Proton/Wine: требуется для Unity/Unreal игр (без этого краши на старте)
      "vm.max_map_count" = 2147483642;
    };
  };

  # ========================================
  # MEMORY / ZRAM
  # ========================================
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 80; # Оставляем 20% RAM для GPU и фоновых задач
    priority = 100; # Приоритет выше disk swap
  };
}
