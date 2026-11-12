# Fish: интерактивный shell, приветствие и sops-хелперы.
_:

{
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

    interactiveShellInit = ''
      fastfetch
    '';

    functions = {
      # sops-init: сканирует все хостовые SSH-ключи, конвертирует в age,
      # записывает список публичных age-ключей в .sops.yaml
      sops-init = ''
        set -l SOPS_CONFIG (git rev-parse --show-toplevel 2>/dev/null || echo .)/.sops.yaml
        set -l SECRETS_FILE (git rev-parse --show-toplevel 2>/dev/null || echo .)/secrets/secrets.yaml

        if not test -f $SOPS_CONFIG
            echo "Ошибка: .sops.yaml не найден в корне репозитория"
            return 1
        end

        # Сканируем все приватные ключи ssh_host_*_key
        set -l AGE_KEYS
        set -l FOUND_KEYS

        for keyfile in /etc/ssh/ssh_host_*_key
            if not test -f $keyfile
                continue
            end

            # Извлекаем публичный ключ и конвертируем в age
            set -l age_pub (ssh-keygen -y -f $keyfile 2>/dev/null | ssh-to-age 2>/dev/null)
            if test -z "$age_pub"
                echo "⚠ Пропущен $keyfile (не удалось сконвертировать в age)"
                continue
            end

            set -l keyname (basename $keyfile)
            echo "✓ $keyname → $age_pub"
            set -a AGE_KEYS $age_pub
            set -a FOUND_KEYS $keyname
        end

        if test -z "$AGE_KEYS"
            echo "Ошибка: не найдено ни одного хостового SSH-ключа в /etc/ssh/"
            echo "Создай ключи: ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N \"\""
            return 1
        end

        # Формируем строку: "age1xxx,age1xxx,age1xxx"
        set -l AGE_PUB_JOINED (string join "," $AGE_KEYS)

        # Подставляем в .sops.yaml (заменяем плейсхолдер ИЛИ перезаписываем age: строку)
        if grep -q "INSERT_AGE_PUBLIC_KEY_HERE" $SOPS_CONFIG 2>/dev/null
            sed -i "s/INSERT_AGE_PUBLIC_KEY_HERE/$AGE_PUB_JOINED/" $SOPS_CONFIG
        else
            # Заменяем существующую строку age:
            sed -i "s/^    age: .*/    age: $AGE_PUB_JOINED/" $SOPS_CONFIG
        end

        echo ""
        echo "✓ .sops.yaml обновлён с " (count $AGE_KEYS) " ключом(ами):"
        for key in $FOUND_KEYS
            echo "    - $key"
        end

        if test -f $SECRETS_FILE
            echo "✓ secrets/secrets.yaml найден — используй 'sops-edit' для редактирования"
        else
            echo "⚠ secrets/secrets.yaml не найден — создай пустой YAML-файл"
        end
      '';

      # sops-edit: открывает secrets/secrets.yaml, автоматически
      # собирая age private keys из всех доступных хостовых SSH-ключей
      sops-edit = ''
        set -l SECRETS_FILE (git rev-parse --show-toplevel 2>/dev/null || echo .)/secrets/secrets.yaml

        if not test -f $SECRETS_FILE
            echo "Ошибка: secrets/secrets.yaml не найден"
            echo "Создай файл и запусти 'sops-init' для первичной настройки"
            return 1
        end

        # Собираем все приватные age-ключи из хостовых SSH-ключей
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
            echo "Ошибка: не найдено ни одного хостового SSH-ключа для расшифровки"
            return 1
        end

        # Объединяем ключи через перевод строки — sops понимает формат newline-separated
        set -l SOPS_AGE_KEY_STRING (string join "\n" $AGE_PRIV_KEYS)

        echo "Используются ключи из: " (count $AGE_PRIV_KEYS) " хостового(ых) SSH-ключа(ей)"
        SOPS_AGE_KEY="$SOPS_AGE_KEY_STRING" sops $SECRETS_FILE
      '';

      # sops-rekey: переподписывает secrets.yaml под новые ключи из .sops.yaml
      # Полезно при добавлении нового хоста или удалении старого
      sops-rekey = ''
        set -l SOPS_CONFIG (git rev-parse --show-toplevel 2>/dev/null || echo .)/.sops.yaml
        set -l SECRETS_FILE (git rev-parse --show-toplevel 2>/dev/null || echo .)/secrets/secrets.yaml

        if not test -f $SECRETS_FILE
            echo "Ошибка: secrets/secrets.yaml не найден"
            return 1
        end

        if not test -f $SOPS_CONFIG
            echo "Ошибка: .sops.yaml не найден в корне репозитория"
            return 1
        end

        echo "Текущие creation_rules из .sops.yaml:"
        grep "age:" $SOPS_CONFIG
        echo ""

        # Показываем текущие ключи в secrets.yaml
        echo "Ключи, которыми зашифрован secrets/secrets.yaml:"
        sops --list-sops $SECRETS_FILE 2>/dev/null
        echo ""

        # Переподписываем секреты под ключи из .sops.yaml
        sops updatekeys $SECRETS_FILE
      '';

      # sops-import-key: считывает приватный SSH-ключ и зашифровывает
      # его содержимое в secrets/secrets.yaml под ключом github_ssh_key
      sops-import-key = ''
        set -l SSH_KEY "$argv[1]"
        if test -z "$SSH_KEY"
            set SSH_KEY ~/.ssh/id_ed25519
        end

        # Разворачиваем ~ до полного пути
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
            echo "Запусти сначала 'sops-init'"
            return 1
        end

        set -l REPO_ROOT (git rev-parse --show-toplevel 2>/dev/null || echo .)

        # Собираем приватные age-ключи для расшифровки/шифрования.
        # Хостовые ключи нужны sops-nix на boot, личный ключ пользователя —
        # для редактирования секретов без sudo.
        set -l AGE_PRIV_KEYS
        for keyfile in /etc/ssh/ssh_host_*_key $HOME/.ssh/id_ed25519
            if not test -f $keyfile
                continue
            end
            set -l age_priv (ssh-to-age -private-key -i $keyfile 2>/dev/null)
            if test -n "$age_priv"
                set -a AGE_PRIV_KEYS $age_priv
            end
        end

        # Первый запуск: secrets.yaml ещё не зашифрован. Шифруем его как есть,
        # чтобы не потерять остальные ключи (например, valen_password).
        if not grep -q '^sops:' $SECRETS_FILE
            set -l TMP_ENC (mktemp --suffix .yaml)
            if test -n "$AGE_PRIV_KEYS"
                SOPS_AGE_KEY=(string join "\n" $AGE_PRIV_KEYS) sops --encrypt --input-type yaml $SECRETS_FILE >$TMP_ENC
            else
                sops --encrypt --input-type yaml $SECRETS_FILE >$TMP_ENC
            end
            or begin
                rm -f $TMP_ENC
                echo "Ошибка: не удалось зашифровать secrets/secrets.yaml"
                return 1
            end
            mv $TMP_ENC $SECRETS_FILE
        end

        # sops set ожидает JSON-строку как значение (jq -Rs экранирует переводы строк).
        # Передаём через stdin, чтобы ключ не светился в списке процессов.
        echo "Чтение ключа: $SSH_KEY"
        echo "Шифрование и запись в secrets/secrets.yaml..."
        if test -n "$AGE_PRIV_KEYS"
            jq -Rs . <"$SSH_KEY" | SOPS_AGE_KEY=(string join "\n" $AGE_PRIV_KEYS) sops set $SECRETS_FILE '["github_ssh_key"]' --value-stdin
        else
            jq -Rs . <"$SSH_KEY" | sops set $SECRETS_FILE '["github_ssh_key"]' --value-stdin
        end

        set -l EXIT $status

        if test $EXIT -eq 0
            echo ""
            echo "✓ SSH-ключ импортирован в secrets/secrets.yaml"
            echo "  Ключ: $SSH_KEY"
            echo "  Секрет: github_ssh_key"
            echo ""
            echo "Зафиксируй изменения:"
            echo "  cd $REPO_ROOT && git add secrets/secrets.yaml"
            echo "  git commit -m 'chore(secrets): import github_ssh_key'"
        else
            echo "Ошибка: не удалось зашифровать секрет"
            echo "Проверь, что age-ключи в .sops.yaml корректны"
            return 1
        end
      '';

      # upgrade: обновляет flake inputs и сразу коммитит flake.lock.
      # Nix сам перечисляет обновлённые inputs (rev + дата) в сообщении коммита.
      upgrade = ''
        set -l repo ~/nixos-config
        cd $repo; or return 1

        set -l dirty 0
        git diff --quiet -- flake.lock; or set dirty 1
        git diff --cached --quiet -- flake.lock; or set dirty 1
        if test $dirty -eq 1
            echo "flake.lock уже изменён — сначала закоммить или откати его:" >&2
            echo "  git add flake.lock && git commit -m 'chore(flake): sync lock'" >&2
            echo "  git checkout -- flake.lock" >&2
            return 1
        end

        set -l before (git rev-parse HEAD)
        nix flake update --commit-lock-file $argv
        or return $status

        if test "$before" = (git rev-parse HEAD)
            echo "Все inputs уже актуальны — коммит не создан."
            return 0
        end

        set -l sha (git rev-parse --short HEAD)
        echo ""
        git --no-pager log -1 --format='%h %s%n%b'
        echo "Откат: git revert $sha"
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
      clear = "pyroclear";
    };
  };
}
