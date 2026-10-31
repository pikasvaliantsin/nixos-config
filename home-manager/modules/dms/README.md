# DMS / niri configs: как это устроено

Всё, что DMS пишет в `$HOME`, — это **out-of-store симлинки в этот каталог**
(см. `dms.nix`, `configRoot`/`link`). То есть источник правды — git, а DMS
правит файлы прямо в репозитории. После переустановки NixOS достаточно
развернуть `nixos-config`: симлинки пересоздадутся, и настройки вернутся как были.

## Что где лежит

```
home-manager/modules/dms/
├── config/                 -> ~/.config/niri/dms          (симлинк на каталог)
│   ├── input.kdl           генерирует DMS (NiriService)
│   ├── binds.kdl
│   ├── alttab.kdl
│   ├── colors.kdl
│   ├── cursor.kdl
│   ├── layout.kdl
│   ├── outputs.kdl
│   ├── windowrules.kdl
│   └── wpblur.kdl
└── app/
    ├── settings.json       -> ~/.config/dms/settings.json
    ├── plugin_settings.json-> ~/.config/dms/plugin_settings.json
    ├── plugins.lock.json   -> ~/.config/dms/plugins.lock.json
    ├── monitors.json       -> ~/.config/dms/monitors.json
    ├── clsettings.json     -> ~/.config/dms/clsettings.json
    ├── themes/             -> ~/.config/dms/themes        (симлинк на каталог)
    └── session.json        -> ~/.local/state/dms/session.json
```

`niri/config.kdl` и `niri/hm.kdl` — тоже out-of-store симлинки (см. `desktop.nix`).

## Что НЕ восстанавливается автоматически

- **Плагины DMS** (`~/.config/dms/plugins/`, ~200 МБ, у каждого свой `.git`).
  Версии зафиксированы в `app/plugins.lock.json`, после переустановки:

  ```bash
  dms plugins restore ~/.config/dms/plugins.lock.json
  ```

  Либо можно перевести нужные плагины на декларативный
  `programs.dank-material-shell.plugins` (src = fetchFromGitHub, rev из lock).
- Кэши (`~/.cache/dms`), образы уведомлений, история буфера — пересоздаются.
- Обои Material генерируются из темы/seed, отдельного файла нет.

## Полезное

- Обновить lock плагинов после установки/апдейта: `dms plugins lock`
  (файл обновится прямо в репозитории).
- Проверить niri-конфиг после правок: `niri validate`.
- Перезапуск шелла: `dms restart` (идёт через `systemctl --user restart dms.service`).
