# Omarchy Quickshell shell, niri port base.
# The upstream tree is vendored under vendor/omarchy-shell and pinned in
# UPSTREAM.md; local changes stay on top of that snapshot.
{ config, pkgs, ... }:

let
  inherit (config.mySystem) dotfilesRoot;

  omarchy = pkgs.callPackage ../../../pkgs/omarchy-shell { };
  omarchyIpc = pkgs.writeShellScriptBin "omarchy-ipc" ''
    exec ${pkgs.quickshell}/bin/quickshell ipc -p "${omarchy}/share/omarchy/shell" "$@"
  '';

  confDir = "${dotfilesRoot}/home-manager/modules/desktop/omarchy";
  stateDir = "${config.home.homeDirectory}/.local/state/omarchy";
in
{
  home.packages = with pkgs; [
    omarchy
    omarchyIpc
    quickshell
    networkmanager
    bluez
    upower
    power-profiles-daemon
    iw
    jq
    iproute2
    iputils
    wl-screenrec
    wf-recorder
    grim
    slurp
    wl-clipboard
    libnotify
    pulseaudio
    wireplumber
    glib
    brightnessctl
    wlsunset
  ];

  # The shell reads ~/.config/omarchy/shell.json first; without it, the
  # packaged default is used. Keep the repo copy canonical.
  xdg.configFile."omarchy/shell.json".source =
    config.lib.file.mkOutOfStoreSymlink "${confDir}/shell.json";
  xdg.configFile."omarchy/niri-style.json".source =
    config.lib.file.mkOutOfStoreSymlink "${confDir}/niri-style.json";

  systemd.user.services.omarchy-shell = {
    Unit = {
      Description = "Omarchy Quickshell shell (niri)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # Do not restart in a tight loop if niri is not up yet.
      StartLimitIntervalSec = 30;
      StartLimitBurst = 5;
    };
    Service = {
      ExecStart = "${omarchy}/bin/omarchy-launch-shell";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = [ "QT_QPA_PLATFORM=wayland" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.activation.omarchyState = config.lib.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p "${stateDir}/current"
    run mkdir -p "${stateDir}/agents/usage"
    run rm -rf "${stateDir}/current/theme"
    run ln -s "${confDir}/theme" "${stateDir}/current/theme"
    # Niri has no Hyprland instance signature. The constant marks this
    # compositor session as already introduced, so the startup cover never
    # maps and the desktop is visible immediately.
    run sh -c 'printf niri > "${stateDir}/background-intro.session-id"'
  '';
}
