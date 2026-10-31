{ pkgs, ... }:

{
  # ========================================
  # PRINTING / SCANNING
  # ========================================
  services.printing = {
    enable = true;
    drivers = [ pkgs.pantum-driver ];
  };

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };

  # Служба для проброса IPP/eSCL через USB
  services.ipp-usb.enable = true;
}
