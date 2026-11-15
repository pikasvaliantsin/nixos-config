# Starship: минимальный prompt без powerline-блоков.
#
# Цвета заданы именами ANSI (blue, purple, yellow, bright-black), а не
# фиксированными hex. Палитру regular*/bright* генерирует theme-set в
# foot.ini и ghostty.conf, поэтому prompt сам следует за темой и не
# требует пересборки при переключении.
{ lib, ... }:

let
  # Языки показываются только в каталогах, где они есть, и без слова
  # "via": глиф плюс версия, если тулчейн доступен.
  languages = [
    "nodejs"
    "bun"
    "deno"
    "rust"
    "golang"
    "c"
    "cpp"
    "java"
    "kotlin"
    "haskell"
    "php"
    "lua"
    "zig"
  ];
  contexts = languages ++ [ "python" "nix_shell" "docker_context" "conda" ];
in
{
  programs.starship = {
    enable = true;

    settings = {
      # Пустая строка между командами: вывод не липнет к prompt.
      add_newline = true;

      # Слева — где мы и что с git; языки/окружения добавляются по факту.
      # Справа — фоновые задачи, длительность и время; ниже — курсор.
      format = lib.concatStringsSep "" (
        [ "$directory" "$git_branch" "$git_state" "$git_status" ]
        ++ map (module: "$" + module) contexts
        ++ [ "$line_break$character" ]
      );
      right_format = "$jobs$cmd_duration$time";

      # Одна машина: OS-иконка каждый prompt не нужна, а user@host
      # появляется только в ssh-сессиях.
      os.disabled = true;
      username = {
        style_user = "bold blue";
        style_root = "bold red";
        format = "[$user]($style)";
      };
      hostname = {
        ssh_only = true;
        style = "bold bright-black";
        format = "[@$hostname]($style) ";
      };

      directory = {
        style = "bold blue";
        read_only_style = "bold red";
        format = "[$path]($style)[$read_only]($read_only_style) ";
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_branch = {
        style = "bold purple";
        format = "[$branch]($style) ";
      };
      git_state = {
        style = "bold red";
        format = "[$state( $progress_current/$progress_total)]($style) ";
      };
      git_status = {
        style = "bold yellow";
        format = "([$all_status$ahead_behind]($style) )";
        conflicted = "✘";
        deleted = "✘";
        renamed = "»";
        modified = "!";
        staged = "+";
        untracked = "?";
        stashed = "≡";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
      };

      jobs = {
        style = "bold blue";
        format = "[$symbol$number]($style) ";
      };
      cmd_duration = {
        min_time = 1500;
        show_milliseconds = false;
        style = "bright-black";
        format = "[$duration]($style) ";
      };
      time = {
        disabled = false;
        time_format = "%H:%M";
        style = "bright-black";
        format = "[$time]($style)";
      };

      # U+276F отсутствует в установленном JetBrains Mono, и foot рисует его
      # тонкой дугой из DejaVu Sans. E0B1 — штатный Nerd Font chevron.
      character = {
        success_symbol = "[](bold green)";
        error_symbol = "[](bold red)";
        vimcmd_symbol = "[](bold green)";
        vimcmd_visual_symbol = "[](bold yellow)";
        vimcmd_replace_symbol = "[](bold red)";
        vimcmd_replace_one_symbol = "[](bold red)";
      };

      python.format = "[$symbol$pyenv_prefix($version )($virtualenv )]($style) ";
    } // lib.genAttrs languages (module: {
      format = "[$symbol($version )]($style) ";
    });
  };
}
