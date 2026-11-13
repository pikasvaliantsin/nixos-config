# TUI-обёртка над mySystem.webapps.
#
# Правит JSON-файл в репозитории, который модуль читает как обычные записи.
# Никакой генерации Nix-кода: сломать конфиг синтаксисом невозможно, а всё
# остаётся в git.
#
# Подстановки: @JSON_FILE@ — файл записей, @DOTFILES@ — корень репозитория,
# @REBUILD@ — команда пересборки (может быть пустой).

readonly FILE="${WEBAPPS_FILE:-@JSON_FILE@}"
readonly DOTFILES="@DOTFILES@"
readonly REBUILD=(@REBUILD@)

readonly ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

err() {
  gum style --foreground 196 "$*" >&2
}

usage() {
  cat <<'EOF'
webapps — декларативные web-приложения (Chromium --app)

  webapps                                    интерактивное меню
  webapps add [--name N] [--url U] [--icon I] [--yes]
  webapps list                               список записей
  webapps remove [ключ]                      удалить запись
  webapps apply                              пересобрать систему

Записи лежат в JSON и читаются home-manager модулем mySystem.webapps.
EOF
}

ensure_file() {
  if [[ ! -f $FILE ]]; then
    mkdir -p "$(dirname "$FILE")"
    printf '{}\n' >"$FILE"
    track_file
  fi
}

# Nix видит только файлы, известные git (flake-источник = git ls-files),
# поэтому новый JSON надо хотя бы пометить intent-to-add.
track_file() {
  command -v git >/dev/null 2>&1 || return 0
  git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local rel
  rel=${FILE#"$DOTFILES"/}
  git -C "$DOTFILES" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1 && return 0
  git -C "$DOTFILES" add -N -- "$rel" >/dev/null 2>&1 || true
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//' |
    cut -c1-48
}

# Chromium называет окно --app по хосту и пути URL: так же, как
# omarchy-webapp-window-class и модуль.
window_class() {
  local url=$1 address host path
  address=${url#*://}
  address=${address%%[?#]*}
  host=${address%%/*}
  path=${address#"$host"}
  host=${host##*@}
  host=${host%%:*}
  printf 'chrome-%s_%s-Default\n' "${host,,}" "${path:-/}" | sed 's|/|_|g'
}

entry_name() {
  jq -r --arg k "$1" '.[$k] | if type == "object" then (.name // $k) else $k end' "$FILE"
}

entry_url() {
  jq -r --arg k "$1" '.[$k] | if type == "object" then .url else . end' "$FILE"
}

normalize_url() {
  local url=$1
  # Любая схема, не только со "//": javascript:/data:/file: должны быть
  # отвергнуты, а не превращены в https://javascript:…
  if [[ ! $url =~ ^[a-zA-Z][a-zA-Z0-9+.-]*: ]]; then
    url="https://$url"
  fi
  [[ ${url,,} =~ ^https?://[^[:space:]]+$ ]] || return 1
  printf '%s' "$url"
}

ask_url() {
  local raw url
  while true; do
    raw=$(gum input --header "URL приложения" --placeholder "https://example.com") || return 1
    [[ -n $raw ]] || continue
    if url=$(normalize_url "$raw"); then
      printf '%s' "$url"
      return 0
    fi
    err "Нужен http(s)-адрес без пробелов"
  done
}

unique_key() {
  local base=$1 key=$1 n=2
  while [[ $(jq -r --arg k "$key" 'has($k)' "$FILE") == true ]]; do
    key="$base-$n"
    n=$((n + 1))
  done
  printf '%s' "$key"
}

write_entry() {
  local key=$1 entry=$2 tmp
  tmp=$(mktemp "$FILE.XXXXXX")
  if ! jq --arg k "$key" --argjson e "$entry" '.[$k] = $e' "$FILE" >"$tmp"; then
    rm -f "$tmp"
    err "Не удалось обновить $FILE"
    return 1
  fi
  if ! jq -e . "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    err "Получился невалидный JSON — ничего не изменил"
    return 1
  fi
  mv "$tmp" "$FILE"
  chmod 644 "$FILE"
}

apply() {
  if (( ${#REBUILD[@]} == 0 )); then
    err "Команда пересборки не задана (mySystem.webapps.tui.rebuildCommand)"
    return 1
  fi
  cd "$DOTFILES"
  exec "${REBUILD[@]}"
}

maybe_apply() {
  (( ${#REBUILD[@]} > 0 )) || return 0
  gum confirm "Пересобрать сейчас (${REBUILD[*]})?" || return 0
  apply
}

add() {
  local name="" url="" icon="" yes=false
  while (( $# > 0 )); do
    case $1 in
      --name)
        name=${2-}
        shift 2
        ;;
      --url)
        url=${2-}
        shift 2
        ;;
      --icon)
        icon=${2-}
        shift 2
        ;;
      --yes)
        yes=true
        shift
        ;;
      -h | --help)
        usage
        return 0
        ;;
      *)
        err "Неизвестный аргумент: $1"
        return 2
        ;;
    esac
  done

  ensure_file

  if [[ -z $name ]]; then
    name=$(gum input --header "Название в лаунчере" --placeholder "Google Maps") || return 0
  fi
  if [[ -z ${name//[[:space:]]/} ]]; then
    err "Название не может быть пустым"
    return 1
  fi

  if [[ -z $url ]]; then
    url=$(ask_url) || return 0
  else
    local raw_url=$url
    if ! url=$(normalize_url "$raw_url"); then
      err "Нужен http(s)-адрес без пробелов: $raw_url"
      return 1
    fi
  fi

  if [[ -z $icon && $yes == false ]]; then
    icon=$(gum input --header "URL иконки" --placeholder "Enter — подобрать автоматически") || return 0
  fi

  local iso=false big=false extra="" meta=""
  if [[ $yes == false ]]; then
    extra=$(gum choose --no-limit \
      --header "Дополнительно (пробел — выбрать, Enter — готово)" \
      "Отдельный профиль Chromium" "Открывать развёрнутым" || true)
    [[ $extra == *"Отдельный"* ]] && iso=true
    [[ $extra == *"развёрнутым"* ]] && big=true
  fi

  if [[ -n $icon ]]; then
    meta=$(curl -fsSL --max-time 15 -o /dev/null -w '%{content_type}' "$icon" 2>/dev/null || true)
    if [[ $meta != image/* ]]; then
      err "⚠ ${icon} не отдаёт картинку (${meta:-нет ответа}); модуль попробует favicon сайта"
      if [[ $yes == false ]]; then
        gum confirm "Всё равно сохранить этот URL иконки?" || return 0
      fi
    fi
  fi

  local key entry
  key=$(unique_key "$(slugify "$name")")
  entry=$(jq -nc --arg name "$name" --arg url "$url" --arg icon "$icon" \
    --argjson iso "$iso" --argjson big "$big" '
      {name: $name, url: $url}
      + (if $icon != "" then {iconUrl: $icon} else {} end)
      + (if $iso then {isolatedProfile: true} else {} end)
      + (if $big then {extraArgs: ["--start-maximized"]} else {} end)
    ')

  if [[ $yes == false ]]; then
    gum style --border rounded --padding "0 1" --margin "1 0" \
      "Имя:     $name" \
      "URL:     $url" \
      "Иконка:  ${icon:-авто (apple-touch-icon → favicon → favicon.ico)}" \
      "Ключ:    $key" \
      "Профиль: $(if [[ $iso == true ]]; then echo отдельный; else echo общий; fi)"
    gum confirm "Добавить?" || return 0
  fi

  write_entry "$key" "$entry" || return 1
  track_file

  if [[ $yes == true ]]; then
    printf '%s\n' "$key"
  else
    gum style --foreground 35 "✓ $name добавлен как $key"
    maybe_apply
  fi
}

list() {
  ensure_file
  local n
  n=$(jq 'length' "$FILE")
  if ((n == 0)); then
    echo "Записей нет."
    return 0
  fi
  jq -r '
    to_entries[]
    | .key as $k
    | [
        $k,
        (.value | if type == "object" then (.name // $k) else $k end),
        (.value | if type == "object" then .url else . end)
      ]
    | @tsv
  ' "$FILE" | column -t -s $'\t' -o '   ' | gum style --border rounded --padding "0 1"
}

remove() {
  ensure_file
  local -a keys
  mapfile -t keys < <(jq -r 'keys[]' "$FILE")
  if ((${#keys[@]} == 0)); then
    echo "Записей нет."
    return 0
  fi

  local key url slug class tmp
  if (($# > 0)); then
    key=$1
    jq -e --arg k "$key" 'has($k)' "$FILE" >/dev/null || {
      err "Нет записи $key"
      return 1
    }
  else
    key=$(printf '%s\n' "${keys[@]}" | gum choose --header "Удалить web app") || return 0
  fi

  url=$(entry_url "$key")
  slug=$(slugify "$key")
  class=$(window_class "$url")

  if (($# == 0)); then
    gum confirm "Удалить «$(entry_name "$key")» ($key)?" || return 0
  fi

  tmp=$(mktemp "$FILE.XXXXXX")
  if jq --arg k "$key" 'del(.[$k])' "$FILE" >"$tmp" && jq -e . "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$FILE"
  else
    rm -f "$tmp"
    err "Не удалось обновить $FILE"
    return 1
  fi
  track_file

  # Иконки, скачанные активацией, home-manager не отслеживает — убираем сами.
  rm -f "$ICON_DIR/webapp-$slug.png" "$ICON_DIR/$class.png" "$ICON_DIR/webapp-$slug.svg" \
    "$ICON_DIR/$class.svg" "$ICON_DIR/.webapp-$slug.url" 2>/dev/null || true

  echo "Удалено: $key. Пересоберите систему, чтобы убрать лаунчер."
}

edit() {
  ensure_file
  local editor=${EDITOR:-vi} backup
  backup=$(mktemp)
  cp "$FILE" "$backup"
  "$editor" "$FILE" || true
  if jq -e . "$FILE" >/dev/null 2>&1; then
    rm -f "$backup"
    track_file
  else
    cp "$backup" "$FILE"
    rm -f "$backup"
    err "JSON невалиден — вернул прежнюю версию"
  fi
}

menu() {
  ensure_file
  local n choice
  local -a items=("Добавить" "Список" "Удалить" "Редактировать JSON")
  if (( ${#REBUILD[@]} > 0 )); then
    items+=("Применить (${REBUILD[*]})")
  fi
  items+=("Выход")

  while true; do
    n=$(jq 'length' "$FILE")
    choice=$(gum choose --header "Web Apps · $n записей · ${FILE#"$DOTFILES"/}" "${items[@]}") || return 0
    case $choice in
      "Добавить") add || true ;;
      "Список") list || true ;;
      "Удалить") remove || true ;;
      "Редактировать JSON") edit || true ;;
      Применить*) maybe_apply || true ;;
      *) return 0 ;;
    esac
  done
}

case ${1:-} in
  add)
    shift
    add "$@"
    ;;
  list)
    list
    ;;
  remove | rm)
    shift
    remove "$@"
    ;;
  apply)
    apply
    ;;
  menu | "")
    menu
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
esac
