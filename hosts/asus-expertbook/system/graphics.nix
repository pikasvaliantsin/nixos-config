{ pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libva
      libva-utils
      # Vulkan loader: без него /run/opengl-driver/lib/libvulkan.so.1
      # отсутствует, и Wine/DXVK не могут получить VK_KHR_surface.
      vulkan-loader
      vulkan-tools
      # libEGL.so.1 / libGL.so.1 (диспетчер GLVND) — нужны Wine для wgl/egl.
      libglvnd
    ];
    extraPackages32 = [
      # 32-битные loader и GLVND нужны лончеру RF4.exe и wine (WINE_LG).
      pkgs.pkgsi686Linux.vulkan-loader
      pkgs.pkgsi686Linux.libglvnd
    ];
  };

  environment = {
    # Wine — не nix-пакет, /etc/ld.so.cache на NixOS нет, поэтому libvulkan.so.1
    # и libEGL.so.1 он может найти только через LD_LIBRARY_PATH.
    sessionVariables.LD_LIBRARY_PATH = [
      "/run/opengl-driver/lib"
      "/run/opengl-driver-32/lib"
    ];

    # 32-битный ELF-загрузчик в стандартном месте /lib/ld-linux.so.2.
    # Нужен Wine (wineboot, explorer, cmd) и 32-битному RF4Launcher.exe:
    # без него любой 32-битный процесс Wine падает с "could not open".
    ldso32 = "${pkgs.pkgsi686Linux.glibc}/lib/ld-linux.so.2";
  };
}
