# Omarchy Quickshell shell, niri port base.
# The upstream tree is vendored under vendor/omarchy-shell and pinned in
# UPSTREAM.md; local changes stay on top of that snapshot.
{ config, pkgs, ... }:

let
  inherit (config.mySystem) dotfilesRoot;

  omarchy = pkgs.callPackage ../../../pkgs/omarchy-shell { };
  omarchySpeedtest = pkgs.callPackage ../../../pkgs/omarchy-speedtest { };
  omarchyIpc = pkgs.writeShellApplication {
    name = "omarchy-ipc";
    runtimeInputs = [ pkgs.quickshell pkgs.procps pkgs.coreutils pkgs.gawk ];
    text = ''
      # Prefer the config path of the actually running shell: a manual/preview
      # instance and the deployed generation can point at different stores.
      shell_cfg=""
      while IFS= read -r pid; do
        cfg=$(tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null | awk 'prev=="-p" { print; exit } { prev=$0 }')
        if [ -n "$cfg" ] && quickshell ipc -p "$cfg" call shell ping >/dev/null 2>&1; then
          shell_cfg="$cfg"
          break
        fi
      done < <(pgrep -f 'quickshell -p .*omarchy/shell' 2>/dev/null || true)
      [ -n "$shell_cfg" ] || shell_cfg=${pkgs.lib.escapeShellArg "${omarchy}/share/omarchy/shell"}
      exec quickshell ipc -p "$shell_cfg" "$@"
    '';
  };

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
    foot
    omarchySpeedtest
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
    # theme-set generates colors.toml/shell.toml under the shared theme state.
    # Prefer that when present; the packaged static theme is only the initial
    # fallback before the first theme switch.
    run sh -c 'if [ -f "${config.home.homeDirectory}/.local/state/theme/current/colors.toml" ]; then ln -s "${config.home.homeDirectory}/.local/state/theme/current" "${stateDir}/current/theme"; else ln -s "${confDir}/theme" "${stateDir}/current/theme"; fi'
    # Niri has no Hyprland instance signature. The constant marks this
    # compositor session as already introduced, so the startup cover never
    # maps and the desktop is visible immediately.
    run sh -c 'printf niri > "${stateDir}/background-intro.session-id"'
  '';
}
