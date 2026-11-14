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

  # pam_exec collapses every non-zero helper exit into PAM_SYSTEM_ERR, which
  # makes Cancel indistinguishable from "no graphical session". This tiny
  # module maps exit 1 to PAM_IGNORE and exit 5 to PAM_AUTH_ERR instead.
  pamOmarchy = pkgs.stdenv.mkDerivation {
    pname = "pam_omarchy";
    version = "1";

    dontUnpack = true;
    buildInputs = [ pkgs.pam ];

    buildPhase = ''
      runHook preBuild
      $CC -shared -fPIC -o pam_omarchy.so ${./pam_omarchy.c} -lpam
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/security
      cp pam_omarchy.so $out/lib/security/pam_omarchy.so
      runHook postInstall
    '';
  };
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
  # graphical session (PAM_IGNORE) falls through to the normal terminal prompt,
  # while an explicit Cancel (PAM_AUTH_ERR) denies immediately.
  security.pam.services.sudo.rules.auth.omarchy-gui = {
    order = config.security.pam.services.sudo.rules.auth.unix.order - 1000;
    control = "[success=done auth_err=die ignore=ignore default=ignore]";
    modulePath = "${pamOmarchy}/lib/security/pam_omarchy.so";
    args = [ "${pamAuth}" ];
  };
}
