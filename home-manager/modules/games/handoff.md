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
   # disko берётся из flake.lock, без ручного хэша
   nix run .#disko -- --mode destroy,format,mount --flake .#gaming-test
   nixos-install --flake .#gaming-test
   ```
   Форматируются только `RF4TEST-ROOT` и `RF4TEST-ESP`; загрузчик ставится
   в отдельный ESP, CachyOS на sda остаётся. Вход: `valen` / `rf4test`.
   Полная установка на sda+nvme — `#asus-expertbook` (там свой полнодисковый
   disko, сносит всё).

   Если разделы уже размечены предыдущим запуском disko, повторно его
   запускать не нужно: достаточно смонтировать существующие сабволюмы
   `@`, `@home`, `@nix`, `@log` и `RF4TEST-ESP`, затем `nixos-install`.
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

## Инвентарь CachyOS-префикса (PortProton)

Снято 2026-11-22 с `/dev/nvme0n1p2` (`/mnt/cachy/valen/Games/rf4/pfx`,
только чтение) до того, как этот префикс отработал на NixOS. Нужно, чтобы
после полной переустановки было видно, чем именно «хорошо работавшая»
версия отличалась от чистого `rf4-install`.

### Происхождение и версии

- префикс — reflink-копия PortProton-префикса, созданного `wine-lg 11-10`
  (`.wine_ver = WINE_LG_11-10`, `version = 11.0-100`);
- запускался через umu 1.4.3 (steamrt4) + **GE-Proton11-12 из nix-сборки**
  (`config_info` ссылается на `/nix/store/w700j12…-proton-ge-bin-GE-Proton11-12-…`),
  то есть Proton на CachyOS и на NixOS — один и тот же билд, обновления
  префикса по существу не было;
- `GAMEID=0`, `WINEPREFIX=~/Games/rf4`, внутри — `pfx/`;
- игра: `RF4Launcher 4.0.18085` (лог 22.11.2026 19:36), каталог
  `drive_c/games/RF4`, 42 ГиБ; весь префикс — 43 ГиБ;
- окружение CachyOS: gamescope 3.17.0, Mesa 26.3.1, ядро 7.3.5-cachyos
  (см. таблицу тестов выше).

Это **только данные**: ни одного Linux-бинарника и ни одного пакета
PortProton для работы на NixOS не нужно.

### Что скопировано

Содержимое `pfx/` → `~/Games/rf4/` (корень WINEPREFIX): `drive_c`,
`system.reg`, `user.reg`, `userdef.reg`, `dosdevices`,
`creation_sync_guard`, `.update-timestamp`, `winetricks.log`, `.wine_ver`.
Служебные файлы umu из родительского `rf4/` (`config_info`, `version`,
`tracked_files`, `pfx.lock`) не копировались — umu создаёт их сам при первом
запуске (вместе с `gstreamer-1.0/` и `shadercache/`); после запуска игры на
NixOS они появились заново. `pfx -> .` создаётся Proton'ом (и продублирован
вручную).

### winetricks-лог (verb'ы, применённые PortProton)

Это канонический список того, что ставилось в префикс:

```
d3dx9
d3dcompiler_33
d3dcompiler_34
d3dcompiler_35
d3dcompiler_36
d3dcompiler_37
d3dcompiler_38
d3dcompiler_39
d3dcompiler_40
d3dcompiler_41
d3dcompiler_42
d3dcompiler_43
d3dcompiler_46
d3dcompiler_47
d3dx10_33
d3dx10_34
d3dx10_35
d3dx10_36
d3dx10_37
d3dx10_38
d3dx10_39
d3dx10_40
d3dx10_41
d3dx10_42
d3dx10_43
d3dx11_42
d3dx11_43
d3dx9_24
d3dx9_25
d3dx9_26
d3dx9_27
d3dx9_28
d3dx9_29
d3dx9_30
d3dx9_31
d3dx9_32
d3dx9_33
d3dx9_34
d3dx9_35
d3dx9_36
d3dx9_37
d3dx9_38
d3dx9_39
d3dx9_40
d3dx9_41
d3dx9_42
d3dx9_43
vcrun2022
isolate_home
sandbox
mfc42
faudio
andale
arial
comicsans
courier
georgia
impact
times
trebuchet
verdana
webdings
corefonts
calibri
physx
tahoma
lucida
7zip
openal
vcrun2005
vcrun2008
vcrun2010
vcrun2012
vcrun2013
based_on_default
```

`isolate_home` и `sandbox` — служебные для PortProton (изоляция домашнего
каталога и sandboxing), для umu/Proton не нужны и на игру не влияют.

### Глобальные DLL-override'ы (user.reg)

```
[Software\\Wine\\DllOverrides]
"*atl100"="native,builtin"  "*atl110"="native,builtin"  "*atl120"="native,builtin"
"*atl80"="native,builtin"   "*atl90"="native,builtin"
"*avcodec-58"="native"      "*avutil-56"="native"        "*swresample-3"="native"
"*concrt140"="native,builtin"  "*FAudio"="native"  "*libwinpthread-1"="native"
"*SDL2"="native"
"*msvcm80"="native,builtin"   "*msvcm90"="native,builtin"
"*msvcp80"="native,builtin"   "*msvcp90"="native,builtin"
"*msvcp100"="native,builtin"  "*msvcp110"="native,builtin"
"*msvcp120"="native,builtin"  "*msvcp140"="native,builtin"
"*msvcp140_1"="native,builtin"  "*msvcp140_2"="native,builtin"
"*msvcp140_atomic_wait"="native,builtin"  "*msvcp140_codecvt_ids"="native,builtin"
"*msvcr80"="native,builtin"   "*msvcr90"="native,builtin"
"*msvcr100"="native,builtin"  "*msvcr110"="native,builtin"
"*msvcr120"="native,builtin"
"*vcamp140"="native,builtin"  "*vccorlib140"="native,builtin"
"*vcomp"="native,builtin"     "*vcomp90"="native,builtin"
"*vcomp100"="native,builtin"  "*vcomp110"="native,builtin"
"*vcomp120"="native,builtin"  "*vcomp140"="native,builtin"
"*vcruntime140"="native,builtin"  "*vcruntime140_1"="native,builtin"
"*xactengine3_0"="native" … "*xactengine3_7"="native"
```

`AppDefaults` в `user.reg` содержат записи для других игр (Avengers,
BlackOps3, FarCry5, ffxvi и т.п.); к RF4 они отношения не имеют — специфичных
для `RF4Launcher.exe`/`rf4_x64.exe` override'ов нет. Из полезного там только
uninstall-запись `C:\Games\RF4` (`ru.rus-fishsoft.rf4_launcher`).

### Дельта против чистого umu + GE-Proton11-12 префикса

Сравнение с префиксом, который `rf4-install` создал на NixOS 22.11 в 22:52
(свежий umu/GE-Proton11-12, тот же путь и скелет: `pfx -> .`, `system.reg`,
`dosdevices` совпали; отличались только `winetricks.log` и `.wine_ver`).

| | CachyOS | свежий `rf4-install` | дельта |
|---|---|---|---|
| `system32` файлов | 934 | 835 | **+99** |
| `syswow64` файлов | 966 | 875 | **+91** |
| файлов в `windows/Fonts` | 48 | 20 | **+28** (27 шрифтов + `corefonts.installed`) |

Состав дельты (system32 / syswow64):

| Группа | system32 | syswow64 | примеры |
|---|---|---|---|
| MFC | 56 | 58 | `mfc100/110/120/140{,.u,chs,cht,deu,enu,esn,fra,ita,jpn,kor,rus}`, `mfcm*`; `mfc42/u` — только в syswow64 |
| XAudio2 | 7 | 7 | `xactengine2_{1,2,3,5,6,8,10}` |
| VC runtime | 6 | 6 | `vcamp110/120/140`, `vccorlib110/120`, `vcruntime140_threads` |
| PhysX | 3 | 3 | `PhysXLoader*`, `PhysXDevice*`, `PhysXUpdateLoader*` |
| D3DX CS | 2 | 2 | `d3dcsx_42`, `d3dcsx_43` |
| OpenAL | 2 | 2 | `OpenAL32.dll`, `wrap_oal.dll` |
| FFmpeg | 3 | — | `avcodec-58`, `avutil-56`, `swresample-3` |
| XAPOFX | 1 | 1 | `XAPOFX1_0.dll` |
| CUDA | 1 | 1 | `cudart64_65` / `cudart32_65` |
| FAudio | 1 | — | `FAudio.dll` |
| SDL2 / pthread | 2 | — | `SDL2.dll`, `libwinpthread-1.dll` |
| wine-lg / старый набор | 15 | 11 | `winegstreamer`, `wineopenxr`, `chakra`, `cldapi`, `ndfapi`, `rtscom`, `thumbcache`, `wkscli`, `windows.graphics`, `windows.networking.connectivity`, `capi2032`, `gphoto2.ds`, `sane.ds`, `twain_32`, `odbcad32.exe`, каталог `driverstore` |

Последняя группа — DLL, которых нет в свежем umu-префиксе и которые Proton
не копирует: они остались от wine-lg и под GE-Proton просто не используются.

Шрифты сверх чистого префикса: corefonts (`arial*`, `times*`, `cour*`,
`georgia*`, `trebuc*`, `verdana*`, `comic*`, `impact`, `andalemo`, `ariblk`),
`calibri*`, `corefonts.installed`.

Что **не** отличается: `d3dx9_*`, `d3dx10_*`, `d3dx11_*`, `d3dcompiler_*`
есть в обоих префиксах по 47 файлов (их приносит Proton), поэтому
одноимённые winetricks-verb'ы на дельту не влияют.

### Прочее состояние префикса

- `dosdevices`: `c: -> ../drive_c`, `z:`/`h:` — относительные вверх; `s: -> /home`,
  `w: -> /mnt`, `x: -> /home/valen`, `d:/e:/f: -> /dev/sdb*` (Ventoy-флешка
  из той сессии, Wine обновляет при старте), `com1..com32 -> /dev/ttyS*`;
- `drive_c/users`: `steamuser` (под ним настройки игры), `valen`, `Public`;
- `config_info` (писала umu на CachyOS): строка 1 — `11.0-100`, строки 2/3 —
  пути nix-сборки GE-Proton11-12 (fonts/lib), строка 8 — `share/default_pfx/`,
  строка 12 — список шаблонов DLL (`d3dcompiler_*.dll,d3dcsx*.dll,d3dx*.dll,
  …msvcp1*.dll,vcruntime1*.dll,ucrtbase.dll,comctl32.dll,ntdll.dll,vulkan-1.dll,…`),
  которые umu учитывает; фактически все они в префиксе присутствовали;
- `tracked_files` многократно упоминает `drive_c/windows/{system32,syswow64}/nvcuda.dll` —
  umu/Proton переустанавливал заглушку nvcuda (NVIDIA-API при iGPU не нужен).

### Что это значит при полной переустановке

1. `rf4-install` даст тот же путь, `pfx -> .` и тот же скелет реестра, но
   **подмножество**: без 99/91 DLL, 28 файлов шрифтов, `winetricks.log`,
   `.wine_ver` и без `Games`-редистов PortProton. Чистый префикс на NixOS
   ещё не проверялся на запуск игры.
2. Если на чистом префиксе игра заработает — ничего восстанавливать не нужно.
   Если нет (типичные симптомы: падение лаунчера/игры на `msvcp*.dll`,
   отсутствие звука XAudio2/OpenAL) — доставлять в префикс:
   `vcrun2005/2008/2010/2012/2013/2022`, `mfc42`, `faudio`, `openal`,
   `physx`, `corefonts`/`calibri` (d3dx/d3dcompiler ставить бессмысленно —
   Proton их и так приносит).
3. Проще и надёжнее — держать бэкап проверенного префикса (43 ГиБ):
   ```bash
   cp -a --reflink=auto ~/Games/rf4 /path/to/backup/rf4
   # восстановление:
   rsync -a /path/to/backup/rf4/ ~/Games/rf4/
   ln -sfn . ~/Games/rf4/pfx   # Proton создаёт и сам
   rf4-gs
   ```
4. Проверка после восстановления: `drive_c/games/RF4/log.txt` (лаунчер),
   `…/LocalLow/Russian Fishing LLC/Russian Fishing 4/Player.log` (Unity),
   базовый FPS — `RF4_GS_HUD=1 RF4_HUD=fps rf4-gs`.

## Примечание про sudo (на будущее)

`pam_faillock` на CachyOS блокирует аккаунт после 3 неудачных попыток, включая
`sudo` без tty. Не запускать sudo-команды из неинтерактивного шелла; при
блокировке ждать `unlock_time` (обычно 600 с) или `faillock --user valen --reset`
под root.
