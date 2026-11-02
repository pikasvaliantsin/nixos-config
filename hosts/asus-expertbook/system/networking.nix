_:

{
  networking = {
    networkmanager.enable = true;

    firewall.enable = true;
  };

  services.resolved.enable = true;

  # Автообнаружение сетевых устройств/принтеров (DNS-SD / mDNS)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
