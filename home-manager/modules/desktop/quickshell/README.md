# Quickshell-бар

Минимальная замена dux-shell: бар + центр уведомлений, без панелей-комбайнов.

## Структура

```
shell.qml                  точка входа: бар на каждый монитор + панель уведомлений
Bar.qml                    бар: воркспейсы niri, заголовок, модули, drag-reorder
NotificationPanel.qml      центр уведомлений (единственное место, где они видны)
Theme.qml                  палитра из ~/.config/theme/palette.json (hot reload)
Niri.qml                   workspaces/окна/раскладка через `niri msg --json event-stream`
Audio.qml                  звук/микрофон через wpctl
Net.qml                    сеть через nmcli
Bt.qml                     bluetooth через bluetoothctl
Weather.qml                погода через wttr.in
Sys.qml                    load/RAM/батарея из /proc и /sys
Notif.qml                  NotificationServer, попапов нет, всё в центре
qmldir                     регистрация синглтонов и компонентов
```

## Буфер обмена

- `Mod+V` или иконка буфера в баре — панель истории (текст и картинки с превью).
- ЛКМ — скопировать, ПКМ — удалить запись, «Очистить» — всю историю.
- `cliphist` хранит историю, картинки складываются в `~/.cache/quickshell/clip/`.
- `Ctrl+Shift+S` — последний скриншот в буфер как `image/png`.
- `Ctrl+Alt+S` — выделить область, сохранить файл и **скопировать путь** (удобно
  вставлять в чат агенту: он откроет картинку по пути).

## Управление

- `quickshell ipc call notifications toggle` — открыть/закрыть центр (бинды: `Mod+N`).
- `quickshell ipc call notifications clear` — очистить историю.
- `quickshell ipc call theme reload` — перечитать палитру (это же делает `theme-set`).
- Перетаскивание модулей: зажать модуль в правой части бара и потянуть влево/вправо.
  Порядок сохраняется в `~/.local/state/quickshell/bar-order.json`.

## Разработка

```bash
# запуск без systemd, с логами в терминал
quickshell -p ~/nixos-config/home-manager/modules/desktop/quickshell

# после правки QML: quickshell перечитывает конфиг сам
# логи прошлого запуска: ~/.cache/quickshell/... либо journalctl --user -u quickshell
```

Сервис: `systemctl --user restart quickshell`.

## Зависимости

`quickshell`, `fuzzel`, `cliphist`, `swayosd`, `gtklock`, `awww`, `waypaper`,
`satty`, `playerctl`, `wlogout`, `impala`, `bluetui`, `wiremix`, `dgop`.

## Откат

Ветка `desktop/minimal-shell`. Предыдущая генерация:
`sudo nixos-rebuild switch --rollback` (или выбрать поколение в загрузчике).
