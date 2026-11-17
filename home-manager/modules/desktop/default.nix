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

  home.packages = [ keybinds mimeDefaults ] ++ (with pkgs; [
    # Jarvis voice assistant runtime dependencies (pactl/notify-send already
    # come from the desktop profile).
    python3
    alacritty
    wtype
    portaudio
  ]);

  home.activation.mimeDefaults = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${mimeDefaults}/bin/mime-defaults || true
  '';

  # Конфиг niri: основной файл и бинды. theme.kdl линкуется в themes.nix.
  xdg.configFile = {
    "niri/config.kdl".source = mkLink "config.kdl";
    "niri/binds.kdl".source = mkLink "binds.kdl";
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };
}
