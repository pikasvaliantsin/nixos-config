# RF4 / gaming handoff (ветка `gaming-test`)

Состояние на 2026-11-22. Ветка `gaming-test` от снимка `77ce17d`.

Цель ветки: **один игровой профиль — `rf4-gs`** — на текущем `configuration.nix`
и **стандартном ядре** (`linuxPackages_latest`). Никаких CachyOS-ядер и
специализаций здесь нет.

Для установки **рядом с CachyOS** добавлен тестовый хост `gaming-test`:
disko форматирует только `RF4TEST-ROOT` / `RF4TEST-ESP` (198 ГиБ + 1 ГиБ
на nvme0n1). CachyOS, `/home` и прочее не затрагиваются.
На тестовой установке sops не импортируется: вход `valen` / `rf4test`.

Хост намеренно минимальный:

- система: hardware/boot/locale/network/services/graphics/nix/users/packages
  из `asus-expertbook`, плюс `custom-edid`; ядро — стандартное
  `linuxPackages_latest`;
- графическая сессия: niri + Xwayland + greetd/tuigreet, **без** DMS,
  dank-greeter, dux и Omarchy;
- игры: только `programs.gamescope` с `CAP_SYS_NICE` и `gamemode`,
  **без** Steam, Sunshine, input-remapper и power-tune;
- home: только `core`, `games/rf4.nix`, Firefox, OpenCode, foot, MangoHud;
  **без** nixvim, superwhisper, Zen, Telegram, DMS/dux и FS25.

Важно: `home-manager/home.nix` (полный домашний конфиг) в этом хосте
**не используется**. Именно из-за него первая попытка установки собирала
FS25 и прочие пользовательские модули: `home.nix` импортирует
`./modules/games/fs25.nix` и весь остальной home, независимо от того, что
в `rf4.nix` оставлен один профиль.

Что установлено из RF4:

- `rf4-gs` — единственная игровая команда;
- `rf4-install` — установщик/ремонт (не профиль);
- `umu-launcher` — для отладки.

`rf4-gamescope` остаётся в модуле как внутренняя реализация: `rf4-gs` — это
обёртка над ней с проверенными на CachyOS параметрами. Команды `rf4`,
`rf4-native`, `rf4-gamescope`, `rf4sim*`, `rf4-stream`, `bite-alarm`,
`reel-hold`, `rf4-wheel-xtest` в этой ветке больше не устанавливаются.

## Проверенный профиль `rf4-gs`

```
gamescope:
  -w 1890 -h 810 -W 2240 -H 960 -r 120
  -S fit
  --framerate-limit 120 --adaptive-sync --rt -f --force-grab-cursor

окружение игры:
  RF4_GS_W=1890 RF4_GS_H=810
  RF4_GS_FILTER=none            → без FSR, линейный апскейл
  RF4_GS_SCALER=fit
  RF4_GS_ADAPTIVE=1
  RF4_GS_MANGO=1                → --mangoapp
  RF4_LSFG_MULTIPLIER=3
  RF4_LSFG_FLOW_SCALE=0.5
  RF4_LSFG_PERFORMANCE_MODE=1
  DXVK cap: dxgi.maxFrameRate=40   (120 / 3)

LSFG грузится только в игре:
  gamescope получает DISABLE_LSFGVK=1 и VK_LOADER_LAYERS_DISABLE,
  игра — LSFGVK_* заново через GAME_ENV.
```

Запуск: `rf4-gs` из терминала.

## Результаты тестов на CachyOS (та же сборка rf4.nix)

Nix 2.36 + системный umu 1.4.3 (steamrt4) + GE-Proton11-12 + системный
gamescope 3.17.0; префикс — reflink-копия PortProton-префикса.

| Профиль | Внутреннее | LSFG | База | На экране |
|---|---|---|---|---|
| `rf4-gs` | 1890x810 linear | 3x / 0.5 / perf | ~33 | **~100** |
| `rf4-old` | 1680x720 + FSR | 2x / 1.0 / off | 29–30 | **60** |
| `rf4` (native) | 2240x960, Wine Wayland | 2x / 1.0 / off | — | завис на загрузке карты |
| PortProton (текущий) | 1890x810 linear | 3x / 0.5 / perf | ~33 | ~100 |

Вывод: **60 FPS с генерацией — это ровно профиль 2x/1.0**, а не «NixOS
тормозит». На CachyOS та же сборка с 3x/0.5 даёт ~100, как PortProton.

## Что оказалось причиной «NixOS был медленным»

1. **Профиль.** 2x / flow 1.0 / performance off физически даёт ~60 при базе 30.
   Коммит `a905439`: «PortProton reached 100+ FPS while our 2x stack stayed at
   50–60 from a 30 FPS base». Позже `70ae8d9` сознательно вернул качество —
   отсюда и ощущение, что NixOS медленный.
2. **Питание/шедулер — шум.** A/B `powerprofilesctl set balanced` дал 2–3 кадра
   (1 базовый). `ananicy`/BORE — проценты, не кратность.
3. **LSFG молча не работал** в части конфигураций: `13eeea3` (env игры без
   `LSFGVK_ENV/XDG_DATA_DIRS`), `d1e5e3a` (двойная загрузка слоя до/в gamescope).
4. **Gamescope без `--rt`.** Security-wrapper с `CAP_SYS_NICE` в `gaming.nix`
   уже был, но в аргументах не было `--rt` → capability не использовалась.
   Исправлено: `ARGS+=(--rt)` в `rf4-gamescope`.
5. **MangoHud.** На CachyOS nix-сборка `mangoapp` вне NixOS падала с
   `GLX: No GLXFBConfigs` и циклически рестартовала. На NixOS nix-сборка
   должна работать; если нет — `RF4_GS_MANGO=0`.
6. **Синхронизация разрешения** писала в `$WINEPREFIX/drive_c`, а реальный
   Proton-префикс — `$WINEPREFIX/pfx/drive_c`. Исправлено: определяется `pfx`.
7. **Клавиатура в gamescope.** Нужны `XKB_DEFAULT_LAYOUT=us,ru`,
   `XKB_DEFAULT_OPTIONS=grp:win_space_toggle,compose:menu`, `DISABLE_XIM=1`,
   `GTK/QT_IM_MODULE=simple`, `XMODIFIERS=@im=none` (старый NixOS-фикс).
8. **Native Wine Wayland + LSFG** нестабилен: на CachyOS завис на загрузке
   карты при 2x/1.0. Для тестов не использовать; gamescope-ветка стабильна.
9. **umu на CachyOS** (не NixOS): системный umu/steamrt4 не пробрасывал
   Vulkan ICD; в native X11-тесте DXVK падал с `Found no drivers`. На NixOS
   umu работает через `/run/opengl-driver`; это CachyOS-грабли, не переносить.
10. **Mesa/ядро.** NixOS-пин: Mesa 26.2.6, ядро 7.3.1; CachyOS: 26.3.1 /
    7.3.5-cachyos. Вклад небольшой, но правки explicit sync/VRR могут влиять.

## Что делать на NixOS

1. Установка рядом с CachyOS (ветка `gaming-test`):
   ```bash
   sudo nix run github:nix-community/disko -- \
     --mode destroy,format,mount --flake /tmp/nixos-config#gaming-test
   sudo nixos-install --flake /tmp/nixos-config#gaming-test
   ```
   Форматируются только `RF4TEST-ROOT` и `RF4TEST-ESP`; загрузчик ставится
   в отдельный ESP, CachyOS на sda остаётся. Вход: `valen` / `rf4test`.
   Полная установка на sda+nvme — `#asus-expertbook` (там свой полнодисковый
   disko, сносит всё).
2. Префикс: `~/Games/rf4/pfx`. После установки можно скопировать готовый из
   CachyOS (раздел `/dev/nvme0n1p2`, 43 ГиБ):
   ```bash
   sudo mount /dev/nvme0n1p2 /mnt/cachy
   mkdir -p ~/Games/rf4
   cp -a /mnt/cachy/valen/Games/rf4/pfx ~/Games/rf4/
   ```
   Или поставить через `rf4-install`. На 198 ГиБ влезает.
3. Играть: `rf4-gs` из терминала.
4. Смотреть **базовый** FPS: в `rf4-gs` MangoHud показывает output; для базы
   `RF4_GS_HUD=1 RF4_HUD=fps rf4-gs` (DXVK HUD).
5. Стандартное ядро. Если захочется тестировать CachyOS-ядро — отдельно,
   через `github:xddxdd/nix-cachyos-kernel`, не в этой ветке.
6. Проверить, что gamescope идёт через `/run/wrappers/bin/gamescope` (cap) и
   в логе нет «No CAP_SYS_NICE»; `--rt` уже в аргументах.

## Чего не делать

- не мерить производительность на `2x / flow 1.0` — это заведомые ~60;
- не запускать native `rf4` с LSFG для тестов (Wayland-ветка нестабильна);
- не ставить `power_dpm_force_performance_level=high` и `renice=10`;
- не полагаться на `gamemoded` (в сессии может быть inactive);
- не использовать nix-сборку `mangoapp` вне NixOS;
- не опускать `--rt` при наличии security-wrapper.

## Открытые вопросы

- Профиль: 1890x810 vs 1960x840, flow 0.5 vs 0.75.
- Ядро: сток 7.3.1 vs cachyos-bore vs zen (отдельная ветка/специализация).
- `scx_lavd` vs BORE на стоковом ядре.
- Mesa 26.2.6 vs 26.3.1.
- Есть ли смысл в Xwayland-варианте gamescope вместо нативного (сейчас
  gamescope сам даёт Xwayland, и это работает).

## Полезные пути/коммиты

- Модуль: `home-manager/modules/games/rf4.nix`.
- Профиль `rf4-gs`: обёртка в этом модуле (1890x810 / 3x / 0.5 / linear).
- Коммиты истории: `a905439`, `70ae8d9`, `d1e5e3a`, `13eeea3`, `827a376`,
  `59e8f39`, `77ce17d`.
- Игра: `~/Games/rf4/pfx/drive_c/games/RF4/RF4Launcher.exe`; лог лаунчера:
  `~/Games/rf4/pfx/drive_c/games/RF4/log.txt`; Unity:
  `~/Games/rf4/pfx/drive_c/users/steamuser/AppData/LocalLow/Russian Fishing LLC/Russian Fishing 4/Player.log`.

## Примечание про sudo (на будущее)

`pam_faillock` на CachyOS блокирует аккаунт после 3 неудачных попыток, включая
`sudo` без tty. Не запускать sudo-команды из неинтерактивного шелла; при
блокировке ждать `unlock_time` (обычно 600 с) или `faillock --user valen --reset`
под root.
