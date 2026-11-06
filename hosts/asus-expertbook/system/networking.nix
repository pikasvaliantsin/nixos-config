_:

{
  networking = {
    networkmanager.enable = true;

    firewall.enable = true;
  };

  services.resolved.enable = true;

  # Удалённый доступ вне домашней сети: Tailscale (WireGuard mesh).
  # После switch: sudo tailscale up
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  # Автообнаружение сетевых устройств/принтеров (DNS-SD / mDNS)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
