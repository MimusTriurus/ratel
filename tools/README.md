# Инструменты

Всё, что лежит в `tools/`: проверки, генераторы данных и обработка ассетов.
У каждого файла в шапке написано подробнее, что он делает, — здесь только
что это, когда запускать и как.

Запускается всё из корня репозитория. Godot не в `PATH`, вместо `godot`
подставьте путь к редактору. На свежем клоне сначала один раз
`godot --path . --headless --import`, иначе `--script` не найдёт
`class_name`. Python — через `py` (на этой машине `python` — заглушка
WindowsApps). Blender — Store-сборка, запускается через
`%LOCALAPPDATA%\Microsoft\WindowsApps\blender-launcher.exe` (здесь
`blender-launcher`); его вывод не виден, поэтому смотрите `--report`.

## Проверки

Ничего не пишут (кроме оговорённого), запускать после изменений в своей
области. Зелёный результат — `all good` / `ok` / отсутствие различий.

| файл | что проверяет | запуск |
|---|---|---|
| `verify_json_maps.gd` | `assets/maps/stage-N.json` несут всё, что несли исходные `.dat` (нужны `.dat` из истории git) | `godot --path . --headless --script tools/verify_json_maps.gd` |
| `verify_json_roundtrip.gd` | `MapIO` записывает каждый этап байт в байт как прочитал; после — `git diff --exit-code assets/maps` | `godot --path . --headless --script tools/verify_json_roundtrip.gd` |
| `verify_map_edit.gd` | кисти, отмена и сохранение 2D-редактора карт; **оставляет `stage-0.json` изменённым нарочно**, потом `git checkout -- assets/maps` | `godot --path . --headless --script tools/verify_map_edit.gd` |
| `verify_flow_field.gd` | построенное поле направлений против поставленного `dirs-N.dat`; `valid` должно быть 100 % | `godot --path . --headless --script tools/verify_flow_field.gd` |
| `verify_backdrop.gd` | этап, нарисованный картинкой, совпадает с тайловым до пикселя; нужно окно | `godot --path . --windowed --resolution 1280x720 --script tools/verify_backdrop.gd` |
| `verify_level3d.gd` | 3D-файлы уровней `assets/level3d/stage-N.json`: round trip, сетка, группы, триггеры, каталог, растры | `godot --path . --headless --script tools/verify_level3d.gd` |
| `verify_level_editor.gd` | редактор 3D-уровней без человека: кисти, отмена, сохранение; с окном ещё и снимки, с `-- --build` сборка | `godot --path . --windowed --resolution 1600x900 --script tools/verify_level_editor.gd` |
| `verify_level3d_audio.gd` | звук 3D-превью: папки обоих режимов, микс, музыка, цепочки частей, адаптивная музыка босса | `godot --path . --headless --script tools/verify_level3d_audio.gd` |

## Карты и поле направлений (2D-игра)

| файл | что делает | запуск |
|---|---|---|
| `map_json.py` | конвертер исходных `.dat`-карт в `stage-N.json` и обратная сверка байт в байт | `py tools/map_json.py export` / `py tools/map_json.py verify` |
| `dirs_build.gd` | перестраивает `assets/maps/dirs-N.dat` по сетке столкновений; только после правки сетки и только свой этап | `godot --path . --headless --script tools/dirs_build.gd -- 3` |
| `bake_stage_image.gd` | запекает тайловую сетку этапа в картинки-фоны `assets/images/levels/stage-N-K.png` | `godot --path . --headless --script tools/bake_stage_image.gd -- all` |

## Спрайты

Одноразовая миграция с девяти листов `sprites-N.png` на атлас на объект.

| файл | что делает | запуск |
|---|---|---|
| `sprite_repack.py` | разложил листы по атласам, пиксели копируются как есть | `py tools/sprite_repack.py` |
| `sprite_verify.py` | сверяет все 264 спрайта с исходными листами (их вернуть из истории git) | `py tools/sprite_verify.py` |
| `sprite_index.py` | пересобирает `assets/images/SPRITES.md`, таблицу имя → атлас → размер | `py tools/sprite_index.py` |

## 3D-уровни

Как это всё связано — в `CLAUDE.md`, раздел «3D level files», и в
`docs/level-editor-plan.md`.

| файл | что делает | запуск |
|---|---|---|
| `level_from_stage.gd` | пишет `assets/level3d/stage-0.json` из карты игры и `jackal_stage1.glb`; перезаписывает файл | `godot --path . --headless --script tools/level_from_stage.gd` |
| `level_ground_rasters.gd` | даёт уровню растры земли и высоты из его полигонов, один раз на уровень | `godot --path . --headless --script tools/level_ground_rasters.gd -- 0` |
| `level_terrain_from_glb.gd` | без аргументов сравнивает землю файла с собранным glb; с `--glb` трассирует землю с ручного уровня | `godot --path . --headless --script tools/level_terrain_from_glb.gd` |
| `level_structures_from_base.gd` | кладёт в файл уровня стены, мост и ворота, снятые `extract_structures.py` | `godot --path . --headless --script tools/level_structures_from_base.gd` |
| `blender/build_level.py` | собирает уровень в Blender из файла уровня поверх базового `.blend`, в `build/level3d/` | `blender-launcher -b resources/3d/jackal_stage1_lowpoly.blend --python tools/blender/build_level.py -- assets/level3d/stage-0.json --out build/level3d/jackal_stage1_gen.blend --glb build/level3d/jackal_stage1_gen.glb --report build/level3d/report.txt` |
| `blender/extract_structures.py` | снимает стены, мост и раму ворот с ручного уровня в JSON | `blender-launcher -b resources/3d/jackal_stage1_lowpoly.blend --python tools/blender/extract_structures.py -- build/level3d/structures.json` |
| `blender/render_top.py` | рендер этапа сверху его камерой или сравнение двух таких рендеров | `blender-launcher -b build/level3d/jackal_stage1_gen.blend --python tools/blender/render_top.py -- --render build/level3d/top_gen.png 50` |

## Звук 3D-превью

| файл | что делает | запуск |
|---|---|---|
| `sfx3d_classic.gd` | собирает `assets/sfx3d/original/` и `assets/music3d/original/` из оригиналов и дозаполняет modern тем, чего там нет; готовые файлы modern не трогает | `godot --path . --headless --script tools/sfx3d_classic.gd` |
| `measure_loudness.gd` | пик и громкость (самые громкие 50 мс) файла — от этого ставится первый уровень нового звука в миксе | `godot --path . --headless --script tools/measure_loudness.gd -- res://assets/sfx3d/modern/gun_0.ogg` |
| `sfx_tails.py` | укорачивает хвосты modern-звуков (эхо и раскаты после удара): исходники берёт из git, пишет в `assets/sfx3d/modern/`; таблица `TAILS` в начале файла | `py tools/sfx_tails.py` (`--listen` — до/после в `build/sfx_tails/`, `имя --try t0 t1` — проба без записи в assets) |
| `sfx_chiptune.py` | звуки режима «Классический (8-bit)»: каждый modern-файл раскладывается по кадрам на регистры NES и проигрывается на модели 2A03 с фильтрами Famicom, по громкости оригинала; `--install` пишет `assets/sfx3d/classic/` ровно с теми же файлами, что в `modern/` (петли без шва, копии оригинала копируются как есть); без него — только пары для прослушивания в `build/sfx3d_chip/index.html`; нужен venv Basic Pitch и ffmpeg | `build/.venv_basic_pitch/Scripts/python tools/sfx_chiptune.py --install` — после любого нового или изменённого modern-звука |
| `music_chiptune.py` | музыка режима «Классический (8-bit)»: ноты modern-треков (MIDI из `build/music3d_pogonya/` и `build/music3d_boss/`) раскладываются на 8 голосов NES и VRC6 (таблица `ARRANGEMENT`) и играются на модели чипов; режется по тем же тактам, что modern, громкость по modern-петле; босс — линейный; нужен venv Basic Pitch и ffmpeg | `build/.venv_basic_pitch/Scripts/python tools/music_chiptune.py --install` (без `--install` — только `build/music_chiptune/`) |
| `audio_check.ps1` | что Windows делает со звуком: устройство вывода, громкость, mute каждого приложения; когда превью молчит | `powershell -ExecutionPolicy Bypass -File tools/audio_check.ps1` |

После любого нового или изменённого modern-звука — `sfx_chiptune.py --install`, чтобы
классика его догнала, затем `godot --path . --headless --import` и `verify_level3d_audio.gd`.

## Не здесь

Программы, а не скрипты, лежат в `src/tools/` и открываются как сцены:
`map_editor.tscn` (2D-редактор карт), `level_editor.tscn` (редактор
3D-уровней), `level3d_preview.tscn` (3D-превью игры). Исходники музыки
(`build/music3d_pogonya/`, `build/music3d_boss/`) лежат в `build/`, который
не попадает в git.
