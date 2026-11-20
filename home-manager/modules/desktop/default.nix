# Desktop-окружение: композитор, бары, порталы, темы, шрифты и монтирование.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  configPath = "${config.mySystem.dotfilesRoot}/home-manager/modules/niri";
  mkLink = file: config.lib.file.mkOutOfStoreSymlink "${configPath}/${file}";

  # Keybinding sheet data for the shell overlay. Reads the live binds file, so
  # the sheet follows the compositor configuration without a rebuild.
  keybinds = pkgs.writeShellApplication {
    name = "omarchy-keybinds";
    runtimeInputs = [ pkgs.python3 ];
    text = ''exec python3 ${../niri/keybinds.py} "$@"'';
  };

  # Fix the stale DankMaterialShell association (dms-open.desktop does not
  # exist) and make the Dux file manager the handler for folders and
  # file-manager URL schemes. Runs after every activation.
  mimeDefaults = pkgs.writeShellApplication {
    name = "mime-defaults";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.xdg-utils
      pkgs.desktop-file-utils
    ];
    text = builtins.readFile ./mime-defaults.sh;
  };
  # Keep the laptop panel attached to the right edge of the external monitor
  # for every HDMI mode, including runtime mode changes from the Display
  # panel. niri's auto placement already does this when eDP has no position,
  # but this also covers config reloads/hotplug and any future layout changes.
  niriBin = "${config.home.profileDirectory}/bin/niri";

  niriOutputLayout = pkgs.writeShellApplication {
    name = "niri-output-layout";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      NIRI="${niriBin}"

      apply() {
        local out hdmi_w hdmi_x edp_x
        out=$("$NIRI" msg --json outputs 2>/dev/null) || return 0
        hdmi_w=$(printf '%s' "$out" | jq -r '."HDMI-A-1".logical.width // empty')
        [ -n "$hdmi_w" ] || return 0
        hdmi_x=$(printf '%s' "$out" | jq -r '."HDMI-A-1".logical.x // empty')
        edp_x=$(printf '%s' "$out" | jq -r '."eDP-1".logical.x // empty')

        if [ "$hdmi_x" != "0" ]; then
          "$NIRI" msg output HDMI-A-1 position set 0 0 >/dev/null 2>&1 || true
        fi
        if [ "$edp_x" != "$hdmi_w" ]; then
          "$NIRI" msg output eDP-1 position set "$hdmi_w" 0 >/dev/null 2>&1 || true
        fi
      }

      # niri may not be up yet when the user service starts.
      while ! "$NIRI" msg version >/dev/null 2>&1; do
        sleep 1
      done

      apply

      "$NIRI" msg event-stream 2>/dev/null | while IFS= read -r line; do
        case "$line" in
          *"Outputs changed"*|*"Config loaded successfully"*) apply ;;
        esac
      done
    '';
  };

in
{
  imports = [
    ./fonts.nix
    ./gtk.nix
    ./portals.nix
    ./udiskie.nix
    ./desktop-tools.nix
    ./omarchy.nix
    ./themes.nix
    inputs.dux-files.homeModules.dux-files
    inputs.dux-calendar.homeModules.dank-calendar
    inputs.dux-search.homeModules.dsearch
  ];

  programs.dux-files.enable = true;

  programs.dank-calendar = {
    enable = true;
    systemd.enable = true;
    settings = {
      use24HourClock = true;
      remindersEnabled = true;
    };
  };

  programs.dsearch = {
    enable = true;
    config = {
      index_path = "${config.home.homeDirectory}/.cache/dsearch/index";
      http_enabled = false;
      listen_addr = "127.0.0.1:43654";
      max_file_bytes = 2097152;
      worker_count = 6;
      index_all_files = true;
      index_xattr_tags = true;
      max_depth = 0;
      text_extensions = [
        ".txt" ".md" ".go" ".py" ".js" ".ts" ".jsx" ".tsx" ".json" ".yaml" ".yml"
        ".toml" ".html" ".css" ".rs" ".c" ".cpp" ".h" ".java" ".rb" ".php" ".sh"
      ];
      index_paths = [{
        path = config.home.homeDirectory;
        max_depth = 6;
        exclude_hidden = true;
        extract_exif = true;
        extract_xattr_tags = false;
        merge_default_exclude_dirs = true;
        exclude_dirs = [
          ".git" ".hg" ".svn" "node_modules" "result" ".cache" "target" "dist"
          "build" "vendor" "__pycache__" ".venv" "venv" ".direnv" ".opencode"
        ];
      }];
    };
  };

  home.packages = [ keybinds mimeDefaults ];

  home.activation.mimeDefaults = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${mimeDefaults}/bin/mime-defaults || true
  '';

  # Конфиг niri: основной файл и бинды. theme.kdl линкуется в themes.nix.
  xdg.configFile = {
    "niri/config.kdl".source = mkLink "config.kdl";
    "niri/binds.kdl".source = mkLink "binds.kdl";
  };

  # Держит eDP-1 левым краем у правого края HDMI-A-1 при любом режиме.
  # Конфиг niri делает это через auto-placement (HDMI pinned x=0, eDP без
  # position), но сервис дополнительно ловит runtime-смены режима из панели.
  systemd.user.services.niri-output-layout = {
    Unit = {
      Description = "Attach eDP-1 to the right edge of HDMI-A-1";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${niriOutputLayout}/bin/niri-output-layout";
      Restart = "always";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
