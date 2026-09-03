# nixos-config/home-manager/modules/shell.nix
# Импорт-хаб: Fish, CLI-утилиты, Ghostty, Git, Fastfetch
{ pkgs, inputs, ... }:

{
  imports = [
    ./shell/cli.nix
  ];

  # Fish Shell — полная конфигурация
  programs.fish = {
    enable = true;
    shellInit = ''
      set -gx EDITOR nvim
      set -gx VISUAL nvim
      set -gx XDG_CURRENT_DESKTOP Niri
      set -gx XDG_SESSION_TYPE wayland
      set -g fish_greeting ""
      set -g __fish_git_prompt_show_informative_status 1
    '';

    # Команда запускается после каждого запуска терминала
    interactiveShellInit = ''
      fastfetch
    '';

    functions = {
      sops-init = ''
        set -l SOPS_CONFIG (git rev-parse --show-toplevel 2>/dev/null || echo .)/.sops.yaml
        set -l SECRETS_FILE (git rev-parse --show-toplevel 2>/dev/null || echo .)/secrets/secrets.yaml

        if not test -f $SOPS_CONFIG
            echo "Ошибка: .sops.yaml не найден в корне репозитория"
            return 1
        end

        # Сканируем все приватные ключи ssh_host_*_key
        for keyfile in /etc/ssh/ssh_host_*_key
            if not test -f $keyfile
                continue
            end
            set -l age_pub (ssh-keygen -y -f $keyfile 2>/dev/null | ssh-to-age 2>/dev/null)
            if test -z "$age_pub"
                echo "⚠ Пропущен $keyfile (не удалось сконвертировать в age)"
                continue
            end
            set -a AGE_KEYS $age_pub
            set -a FOUND_KEYS (basename $keyfile)
        end

        if test -z "$AGE_KEYS"
            echo "Ошибка: не найдено ни одного хостового SSH-ключа в /etc/ssh/"
            return 1
        end

        # Подставляем в .sops.yaml
        sed -i "s|INSERT_AGE_PUBLIC_KEY_HERE|$(string join ',' $AGE_KEYS)|" $SOPS_CONFIG
        echo ""
        echo "✓ .sops.yaml обновлён с " (count $AGE_KEYS) " ключом(ами):"
        for key in $FOUND_KEYS
            echo "    - $key"
        end
        if test -f $SECRETS_FILE
            echo "✓ secrets/secrets.yaml найден — используй 'sops-edit'"
        else
            echo "⚠ secrets/secrets.yaml не найден"
        end
      '';

      sops-edit = ''
        set -l SECRETS_FILE (git rev-parse --show-toplevel 2>/dev/null || echo .)/secrets/secrets.yaml
        if not test -f $SECRETS_FILE
            echo "Ошибка: secrets/secrets.yaml не найден"
            return 1
        end

        set -l AGE_PRIV_KEYS
        for keyfile in /etc/ssh/ssh_host_*_key
            if not test -f $keyfile
                continue
            end
            set -l age_priv (ssh-to-age -private-key -i $keyfile 2>/dev/null)
            if test -n "$age_priv"
                set -a AGE_PRIV_KEYS $age_priv
            end
        end

        if test -z "$AGE_PRIV_KEYS"
            echo "Ошибка: нет приватных ключей для расшифровки"
            return 1
        end

        SOPS_AGE_KEY=(string join "\n" $AGE_PRIV_KEYS) sops $SECRETS_FILE
      '';

      sops-rekey = ''
        set -l SOPS_CONFIG (git rev-parse --show-toplevel 2>/dev/null || echo .)/.sops.yaml
        set -l SECRETS_FILE (git rev-parse --show-toplevel 2>/dev/null || echo .)/secrets/secrets.yaml

        if not test -f $SECRETS_FILE
            echo "Ошибка: secrets/secrets.yaml не найден"
            return 1
        end
        if not test -f $SOPS_CONFIG
            echo "Ошибка: .sops.yaml не найден"
            return 1
        end

        sops updatekeys $SECRETS_FILE
      '';

      sops-import-key = ''
        set -l SSH_KEY "$argv[1]"
        if test -z "$SSH_KEY"
            set SSH_KEY ~/.ssh/id_ed25519
        end

        if string match -q "~/*" "$SSH_KEY"
            set SSH_KEY (string replace "~" $HOME "$SSH_KEY")
        end

        if not test -f "$SSH_KEY"
            echo "Ошибка: файл не найден: $SSH_KEY"
            return 1
        end

        set -l SECRETS_FILE (git rev-parse --show-toplevel 2>/dev/null || echo .)/secrets/secrets.yaml
        if not test -f $SECRETS_FILE
            echo "Ошибка: secrets/secrets.yaml не найден"
            return 1
        end

        echo "Чтение ключа: $SSH_KEY"
        set -l KEY_LINES (cat "$SSH_KEY")

        set -l TMP_YAML (mktemp --suffix .yaml)
        printf 'github_ssh_key: |\n' > $TMP_YAML
        for line in $KEY_LINES
            printf '  %s\n' "$line" >> $TMP_YAML
        end

        sops --encrypt --input-type yaml $TMP_YAML > $SECRETS_FILE
        rm -f $TMP_YAML
        echo "✓ Ключ зашифрован и сохранён в secrets/secrets.yaml"
      '';
    };

    shellAliases = {
      ls = "lsd";
      ll = "ls -l";
      la = "ls -a";
      ff = "fastfetch";
      tree = "lsd --tree";
      edit = "nvim";
      cat = "bat";
      update = "cd ~/nixos-config && nh os switch .#asus-expertbook";
      upgrade = "cd ~/nixos-config && nix flake update";
      stui = "steam-tui -c steamcmd -s ~/.local/share/Steam -u valentaen312";
      clear = "pyroclear";
    };
  };

  # Git Конфигурация
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Valentin Pikas";
        email = "pikasvaliantsin@github.com";
      };
      core.editor = "nvim";
      init.defaultBranch = "main";
      color.ui = true;
      alias = {
        co = "checkout";
        br = "branch";
        ci = "commit";
        st = "status";
        lg = "log --oneline --graph --all";
      };
    };
  };

  # Терминал Ghostty
  programs.ghostty = {
    enable = true;
    settings = {
      background-opacity = 0.7;
      window-decoration = true;
      font-family = "JetBrains Mono";
      font-size = 12;
      cursor-style = "bar";
      keybind = [
        "super+space=ignore"
        "ctrl+c=copy_to_clipboard"
        "ctrl+v=paste_from_clipboard"
        "ctrl+shift+c=text:\\x03"
      ];
    };
  };

  # Fastfetch
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "small";
        padding = {
          top = 1;
          left = 2;
        };
      };
      display = {
        separator = "  ";
        key = {
          width = 16;
        };
      };
      modules = [
        "break"
        {
          type = "title";
          format = "  {user-name-colored}@{host-name-colored}";
        }
        {
          type = "custom";
          format = "  ┌──────────────────────────────────────────────────┐";
        }
        {
          type = "os";
          key = "  │ 󰍹 os";
          keyColor = "31";
        }
        {
          type = "kernel";
          key = "  │ 󰌽 kernel";
          keyColor = "32";
        }
        {
          type = "uptime";
          key = "  │ 󰅐 uptime";
          keyColor = "33";
        }
        {
          type = "wm";
          key = "  │ 󰨇 wm";
          keyColor = "34";
        }
        {
          type = "shell";
          key = "  │ 󰞷 shell";
          keyColor = "35";
        }
        {
          type = "cpu";
          key = "  │ 󰻠 cpu";
          keyColor = "31";
        }
        {
          type = "memory";
          key = "  │ 󰍛 memory";
          keyColor = "33";
          format = "{1} / {2} ({3})";
        }
        {
          type = "swap";
          key = "  │ 󰓡 swap";
          keyColor = "33";
          format = "{1} / {2} ({3})";
        }
        {
          type = "disk";
          key = "  │ 󰋊 root (/)";
          keyColor = "34";
          folders = "/";
        }
        {
          type = "disk";
          key = "  │ 󰋊 home";
          keyColor = "34";
          folders = "/home";
        }
        {
          type = "custom";
          format = "  └──────────────────────────────────────────────────┘";
        }
        "break"
        {
          type = "colors";
          paddingLeft = 2;
          symbol = "circle";
        }
        "break"
      ];
    };
  };
}
