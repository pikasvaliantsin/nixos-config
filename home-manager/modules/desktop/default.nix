# Desktop-окружение: композитор, бары, порталы, темы, шрифты и монтирование.
{
  config,
  inputs,
  ...
}:

let
  configPath = "${config.mySystem.dotfilesRoot}/home-manager/modules/niri";
  mkLink = file: config.lib.file.mkOutOfStoreSymlink "${configPath}/${file}";
in
{
  imports = [
    ./fonts.nix
    ./gtk.nix
    ./portals.nix
    ./udiskie.nix
    ./webapps.nix
    ./webapps-tui.nix
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
