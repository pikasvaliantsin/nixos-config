{ pkgs, ... }:

{
  # ========================================
  # PRINTING / SCANNING
  # ========================================
  services = {
    printing = {
      enable = true;
      drivers = [ pkgs.pantum-driver ];
    };

    # Служба для проброса IPP/eSCL через USB
    ipp-usb.enable = true;
  };

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };
}
