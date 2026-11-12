# CS2 на ASUS ExpertBook (Ryzen 5 5625U + Vega 7)

Цель: стабильные 100+ FPS в 1280x960 на внешнем 21:9 @ 120 Гц.

## Что уже сделано в конфиге

| Файл | Изменение | Зачем |
| --- | --- | --- |
| `system/services.nix` | `charger.turbo = "always"` | `turbo=auto` не возвращал boost после батареи: CPU жил на 2.3 ГГц вместо 4.35 ГГц |
| `system/gaming.nix` | скрипт `cs2-power-tune` + GameMode `custom.start/end` | на время игры включает `platform_profile=performance` (поднимает лимит package power) и `amdgpu` DPM `high`; понижает `vm.swappiness` до 100, после игры возвращает всё назад |
| `system/gaming.nix` | polkit-правило для gamemode | штатная политика gamemode требует пароль (`allow_active=no`), из-за чего governor/`/proc/sys`-твики молча не применялись |
| `system/gaming.nix` | NOPASSWD только на `cs2-power-tune` | скрипт принимает лишь `start`/`stop` и пишет только в `platform_profile`, DPM и `swappiness` |
| `system/users.nix` | группа `gamemode` | нужна для `renice=10` (CAP_SYS_NICE) |
| `system/graphics.nix` | `MESA_SHADER_CACHE_MAX_SIZE=4G` | кэш пайплайнов CS2 не вытесняется другими играми → меньше фризов при первом матче |

Ядро/GTT не трогали: `mem_info_gtt_total` уже ~8 ГБ, `amdgpu.gttsize` не нужен.

## Применение

```bash
sudo nixos-rebuild switch --flake /home/valen/nixos-config#asus-expertbook
```

После этого **перелогиниться** (или перезагрузиться) — membership в группе `gamemode` подхватывается только новой сессией.

Проверка:

```bash
cat /sys/devices/system/cpu/cpufreq/boost          # 1
cat /sys/firmware/acpi/platform_profile            # balanced вне игры
systemctl --user status gamemoded                  # активен во время игры
sudo dmidecode -t memory | grep -E "Size|Locator|Speed|Rank"
```

Если последняя команда показывает **один** модуль — это single-channel, и это главный
потолок для Vega 7 (до −30…40 % FPS). Второй SO-DIMM даст больше, чем любой софт-тюнинг.

## Установка CS2

Steam → установить Counter-Strike 2 (≈73 ГБ). Игра нативная, Proton не нужен.

## Параметры запуска

Steam → CS2 → Свойства → Параметры запуска.

**21:9, 4:3 растянутое (рекомендую):**

```text
gamescope -w 1280 -h 960 -W 2240 -H 960 -S stretch -F linear -r 120 -f --backend wayland --force-grab-cursor --adaptive-sync -- gamemoderun %command% -novid -nojoy
```

**21:9, 4:3 без растяжения (чёрные поля):** заменить `-S stretch` на `-S fit`.

**Экран ноутбука 1920x1080@60:**

```text
gamescope -w 1280 -h 960 -W 1920 -H 1080 -S stretch -F linear -r 60 -f --backend wayland --force-grab-cursor -- gamemoderun %command% -novid -nojoy
```

**С оверлеем для замера:** добавить `mangohud` перед `%command%`
(`... -- gamemoderun mangohud %command%`). Во время игры оверлей лучше выключать.

`-r 120` — это лимитер gamescope под герцовку монитора: меньше нагрева и стабильнее
буст на 15-ваттном APU. Если хочется максимум отзывчивости — `-r 0` и `fps_max 0`.

## Настройки видео в CS2

| Параметр | Значение |
| --- | --- |
| Разрешение | 1280x960 |
| Режим экрана | Полноэкранный |
| Соотношение сторон | 4:3 |
| Частота | 120 Гц |
| Вертикальная синхронизация | Выкл |
| Boost Player Contrast | Вкл (влияния на FPS нет) |
| Сглаживание (MSAA) | **Выкл** |
| Global Shadow Quality | Низкое |
| Model / Texture Detail | Низкое |
| Texture Filtering | Anisotropic 4x (билинар — если нужен каждый кадр) |
| Shader Detail | Низкое |
| Particle Detail | Низкое |
| Ambient Occlusion | Выкл |
| High Dynamic Range | Качество → Performance |
| FidelityFX Super Resolution | Выкл; если не хватает до 100 — Quality |

FSR в CS2 — это апскейл: Quality рисует ~0.67 от 1280x960 и растягивает. Картинка
мыльнее, но даёт примерно +30–40 % FPS. Включать только если нативно меньше 100.

## autoexec

Путь: `.../steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg/autoexec.cfg`

```cfg
fps_max 0
fps_max_ui 60
snd_mixahead 0.05
```

CS2 вырезал почти все старые перф-cvar'ы (`cl_forcepreload`, `mat_queue_mode` и т.п.),
поэтому «простыня» из CS:GO только вредит. `-console` в параметрах запуска, затем
`exec autoexec` один раз.

## Steam

Настройки → В игре → **Steam Overlay выключить** (лишний Vulkan-слой в игре не нужен).

## Чего ждать

- 1280x960, всё на низком, турбо включён, профиль `performance`: ориентировочно
  **80–110 FPS**, просадки в дымах/на molotov — до 60–70.
- Стабильные 100+ гарантируются только с FSR Quality или при dual-channel RAM.
- Перед игрой закрыть браузеры: в простое занято ~7.5 ГБ из 15, CS2 просит ещё 6–8 ГБ,
  иначе ядро уходит в zRAM и появляются статтеры (частично лечится `swappiness=100`
  из `cs2-power-tune`).

## Замеры до/после замены термопасты

1. `sudo nixos-rebuild switch --flake /home/valen/nixos-config#asus-expertbook`, перелогин.
2. Только от сети — на батарее `auto-cpufreq` режет и governor, и turbo.
3. В параметры запуска добавить `mangohud` перед `%command%`; оверлей покажет
   температуры, частоты и потребление CPU/GPU.
4. Один и тот же сценарий оба раза: `de_dust2`, Deathmatch с ботами, 10 минут,
   одинаковые настройки видео.
5. Смотреть **avg FPS и 1% low**. Для точных цифр — `Shift+F2` (лог в
   `~/bench/*.csv`), потом сравнить средний frametime и хвост 99-го перцентиля.
6. Параллельно в терминале: `sensors` (k10temp + amdgpu) и `nvtop`.

После замены пасты ориентир — минус 5–15 °C под нагрузкой и более ровный
`gpu_clock` без провалов; если температуры те же, проверить прижим радиатора
и забитый вентилятор.

## Откат

```bash
sudo nixos-rebuild switch --rollback
```
