# Обход зависания Samsung PM9A1 (MZVL2512HCJQ-00B00) в D3/низком потреблении.
#
# Симптомы без обхода:
#   - s2idle/Modern Standby зависает намертво, помогает только снятие питания;
#   - Windows: BSOD 0x154 UNEXPECTED_STORE_EXCEPTION и 0x3b,
#     stornvme.sys, c0000006 (in-page I/O error);
#   - Kernel-PnP 410: диск PCI\VEN_144D&DEV_A80A отваливается после пробуждения.
#
# Что делает модуль:
#   1. Отключает ACPI storage-D3 quirk (noacpi=1), из-за которого ядро
#      ставит simple_suspend и полностью выключает контроллер при сне.
#   2. Отключает APST — автономные переходы питания NVMe.
#   3. Запрещает D3cold для NVMe и его PCIe-моста при загрузке и перед каждым сном.
#
# Проверить после активации:
#   cat /sys/class/nvme/nvme0/quirks
#     -> не должно быть simple_suspend
#   cat /sys/module/nvme_core/parameters/default_ps_max_latency_us
#     -> 0
#   cat /sys/bus/pci/devices/0000:03:00.0/d3cold_allowed
#     -> 0
{ ... }:

{
  boot.kernelParams = [
    # Отключаем ACPI storage-D3 quirk. Именно из-за него ядро ставит
    # NVME_QUIRK_SIMPLE_SUSPEND и полностью выключает контроллер при сне.
    #
    # Важно: nvme.quirks=144d:a80a:^simple_suspend на ядре 7.3.1 вызывает
    # page fault в quirks_param_set() при загрузке модуля nvme — NVMe не
    # инициализируется, /home не монтируется, графика не стартует.
    # Поэтому используем noacpi=1: тот же эффект без сломанного парсера.
    "nvme.noacpi=1"

    # Отключаем Autonomous Power State Transition: диск не будет сам уходить
    # в глубокие PS-состояния в простое.
    "nvme_core.default_ps_max_latency_us=0"
  ];

  # На случай, если атрибут сбросится после resume, выставляем его и при загрузке.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:03:00.0", ATTR{d3cold_allowed}="0"
    ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:00:02.4", ATTR{d3cold_allowed}="0"
  '';

  # И перед каждым сном — гарантированно, даже если udev не успел.
  systemd.services.nvme-no-d3cold = {
    description = "Disable D3cold for Samsung PM9A1 before sleep";
    before = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];

    script = ''
      for dev in 0000:03:00.0 0000:00:02.4; do
        if [ -e "/sys/bus/pci/devices/$dev/d3cold_allowed" ]; then
          echo 0 > "/sys/bus/pci/devices/$dev/d3cold_allowed"
        fi
      done
    '';

    serviceConfig.Type = "oneshot";
  };
}
