# Runtime sudoers fragments for the temporary passwordless-sudo button.
# NixOS generates /etc/sudoers, but sudo supports including a directory;
# omarchy-sudo-passwordless writes and removes its own validated rule there.
{ ... }:

{
  security.sudo.extraConfig = ''
    #includedir /etc/sudoers.d
  '';

  systemd.tmpfiles.rules = [
    "d /etc/sudoers.d 0750 root root -"
  ];
}
