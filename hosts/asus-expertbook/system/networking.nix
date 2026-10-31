_:

{
  networking = {
    networkmanager.enable = true;

    # Файрвол с поддержкой NetBird
    firewall = {
      enable = true;
      trustedInterfaces = [ "wt0" ];
      checkReversePath = "loose";
      allowedUDPPorts = [ 51820 ];
    };
  };

  services.resolved.enable = true;

  # Автообнаружение сетевых устройств/принтеров (DNS-SD / mDNS)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
