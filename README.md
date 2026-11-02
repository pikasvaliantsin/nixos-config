# nixos-config

Декларативная конфигурация NixOS для **ASUS ExpertBook** (AMD Vega 7, Niri + DMS)
на flakes + Home Manager.

## Структура

```text
.
├── flake.nix                 # вход, inputs, nixosConfigurations, formatter
├── flake.lock
├── secrets/                  # sops-зашифрованные секреты
├── hosts/
│   └── asus-expertbook/
│       ├── configuration.nix # точка входа хоста: imports, hostName, stateVersion
│       ├── hardware.nix      # автогенерация оборудования
│       ├── disko.nix         # разметка дисков (GPT, Btrfs, zram)
│       ├── sops.nix          # sops-nix и пути к ключам
│       ├── desktop/
│       │   ├── niri.nix      # Niri, DMS, greeter, Xwayland, XKB, порталы
│       │   └── custom-edid.nix
│       └── system/
│           ├── boot.nix      # загрузчик, ядро, sysctl, zram
│           ├── locale.nix    # timezone, i18n, консоль
│           ├── networking.nix
│           ├── nix.nix       # настройки Nix, allowUnfree, overlays
│           ├── overlays.nix  # оверлеи пакетов
│           ├── steam-extra-pkgs.nix
│           ├── graphics.nix  # VA-API, Vulkan, 32-bit, Wine
│           ├── gaming.nix    # Steam, GameMode, Gamescope
│           ├── services.nix  # звук, Bluetooth, keyring, питание
│           ├── printing.nix  # печать, сканер, ipp-usb
│           ├── users.nix
│           └── packages.nix  # минимальный набор системных пакетов
└── home-manager/
    ├── home.nix              # точка входа пользователя: imports
    └── modules/
        ├── core.nix          # home.* и mySystem.dotfilesRoot
        ├── core/secrets.nix  # установка SSH-ключа из sops
        ├── shell.nix         # хаб: cli/fish/git/terminal/fastfetch
        ├── shell/
        ├── editors/          # NixVim, dev-инструменты
        ├── browsers/
        ├── comms/
        ├── media/
        ├── productivity/
        ├── desktop/          # хаб: fonts/gtk/keyring/portals/udiskie
        ├── dms/              # DMS: app/ и config/ — живые конфиги
        ├── niri/             # config.kdl, hm.kdl
        └── games/            # games, rf4
```

Принцип: `configuration.nix` и `home.nix` — только import-хабы. Всё остальное —
небольшие модули, сгруппированные по смыслу.

## Основные команды

```bash
# Пересобрать систему
nh os switch .#asus-expertbook
# (эквивалент)
sudo nixos-rebuild switch --flake .#asus-expertbook

# Обновить inputs
nix flake update

# Форматирование
nix fmt

# Проверки без сборки
nix eval --raw .#nixosConfigurations.asus-expertbook.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.asus-expertbook.config.home-manager.users.valen.home.activationPackage.drvPath
nix run nixpkgs#statix -- check .
nix run nixpkgs#deadnix -- --fail .
```

## Секреты

- Секреты лежат в `secrets/secrets.yaml` и зашифрованы sops.
- Публичные age-ключи хоста — в `.sops.yaml`.
- В fish доступны хелперы: `sops-init`, `sops-edit`, `sops-rekey`, `sops-import-key`.
- Плейнтекст-пароли и приватные ключи в git не попадают.

## DMS и живые конфиги

DMS всегда включён через NixOS-модуль (`hosts/asus-expertbook/desktop/niri.nix`).
Его состояние (`settings.json`, `themes/`, фрагменты niri `*.kdl`) лежит в
`home-manager/modules/dms/` и подключено out-of-store симлинками. DMS пишет
изменения прямо в репозиторий, поэтому они переживают переустановку.

`mySystem.dotfilesRoot` (по умолчанию `~/nixos-config`) задаёт, на какой
checkout указывают симлинки. Это позволяет использовать git worktree со своим
набором живых конфигов.

Подробности — в `home-manager/modules/dms/README.md`.

## Соглашения

- 2 пробела, форматирование `nixfmt` (RFC style).
- Комментарии и документация — по-русски.
- Новый модуль подключается через `imports` в родительском хабе.
- Системные настройки — в `hosts/<host>/system/`, десктоп — в `hosts/<host>/desktop/`.
- Пользовательские приложения — в `home-manager/modules/<группа>/`.
- `stateVersion` меняется только осознанно при обновлении релиза NixOS.
