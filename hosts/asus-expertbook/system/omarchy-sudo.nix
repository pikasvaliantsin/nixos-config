# Runtime sudoers fragments for the temporary passwordless-sudo button.
# NixOS generates /etc/sudoers, but sudo supports including a directory;
# omarchy-sudo-passwordless writes and removes its own validated rule there.
#
# sudo also gets a graphical PAM helper. It asks the Quickshell auth dialog
# for password or fingerprint, verifies the answer itself, and falls through to
# the normal fprintd/unix stack when no graphical session is reachable.
{ config, pkgs, ... }:

let
  pamAuth = pkgs.writeScript "omarchy-pam-auth" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.replaceStrings
      [ "@PAMTESTER@" "@FPRINTD@" ]
      [ "${pkgs.pamtester}/bin/pamtester" "${pkgs.fprintd}/bin/fprintd-verify" ]
      (builtins.readFile ./omarchy-pam-auth.py)}
  '';
in
{
  security.sudo.extraConfig = ''
    #includedir /etc/sudoers.d
  '';

  systemd.tmpfiles.rules = [
    "d /etc/sudoers.d 0750 root root -"
  ];

  # Password-only PAM stack for the helper. It must never call pam_fprintd:
  # the helper verifies fingerprint itself and lets the dialog choose.
  security.pam.services.omarchy-password.text = ''
    auth required ${config.security.pam.pam_unixModulePath} likeauth
    account required ${config.security.pam.pam_unixModulePath}
  '';

  # Runs before fprintd/unix. A successful dialog stops the stack; a missing
  # graphical session (pam_exec service error) falls through to the normal
  # terminal prompt, while an explicit Cancel (auth error) denies immediately.
  security.pam.services.sudo.rules.auth.omarchy-gui = {
    order = config.security.pam.services.sudo.rules.auth.unix.order - 1000;
    control = "[success=done auth_err=die default=ignore]";
    modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
    args = [ "${pamAuth}" ];
  };
}
