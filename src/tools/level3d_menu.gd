# The 3D preview's Escape menu: continue, a new game for one player or two,
# settings, quit, over the stage
# frozen by pausing the tree. The settings are six tabs: five of
# Level3DSettings -- graphics (the camera and the look), interface (what the
# HUD shows, where and how big), sound (classic or modern, the volumes, the
# enemies' fire), controls (the keys, how the BTR drives and how it fires) and
# cheats -- and the mixer, the game's own gain for every sound and every part
# of the music in each mode, which is Level3DAudio's mix and is saved into the
# project rather than the player's settings. Every settings change is handed
# back through `changed` at once, the menu staying open, so a switch shows
# what it does behind it.
#
# The game's own in-game menu (GameMode._open_menu) is drawn with the game's
# font through Main; this one is Godot's controls, as the preview's HUD is a
# Label: the preview has no Main to draw through.
#
# Escape goes back a step: out of a key prompt, out of the settings, and from
# the first page back to the stage.
class_name Level3DMenu
extends CanvasLayer

const FONT_SIZE := 24
# The headings' colour, and a ticked box's.
const ACCENT := Color(1.0, 0.8, 0.3)
# The boxes' size in pixels of the 2048x1152 layout; drawn at ICON_OVERSAMPLE
# times that, so that they stay sharp scaled up to a bigger screen.
const ICON_SIZE := 26
const ICON_OVERSAMPLE := 2
# The Sound tab's sliders, one for each of the modern mode's sounds
# (Level3DAudio.SOUNDS), under a heading for each kind. enemy_hit is left out:
# it is only the original's layer under explode, which the modern mode's
# "blast" replaces. tools/verify_level3d_audio.gd checks that nothing else is.
const SOUND_GROUPS := [
	["Оружие BTR", [["gun", "Пулемёт"], ["grenade_launch", "Пуск гранаты"], ["rocket_launch", "Пуск ракеты"], ["rocket_flight", "Полёт ракеты"]]],
	["Попадания", [["hit_ground", "По земле"], ["hit_water", "По воде"], ["hit_hard", "По бетону и стенам"],
			["hit_dull", "По хижинам и воротам"],
			["hit_armor", "По броне: пулемёт"], ["hit_armor_blast", "По броне: ракета или мина"]]],
	["Выстрелы врагов", [["enemy_mg", "Пулемёты солдат"], ["enemy_cannon", "Пушки: бункеры, танки, лодки"]]],
	["Взрывы", [["blast_small", "Граната"], ["blast_missile", "Ракета"], ["blast_water", "В воде"],
			["blast", "Уничтожение врага"], ["building", "Разрушение здания"], ["breach_gun", "Пробитие танка босса: пулемёт"],
			["breach_blast", "Пробитие танка босса: ракета или мина"],
			["player_explodes", "Гибель BTR"], ["soldier_death_gun", "Гибель солдата от пулемёта"],
			["soldier_death_blast", "Гибель солдата от ракеты или мины"],
			["soldier_death_run_over", "Гибель солдата под колёсами"]]],
	["Двигатели", [["btr_idle", "BTR на холостых"], ["btr_drive", "BTR в движении"], ["tank_engine", "Танки"],
			["boat_engine", "Лодки"], ["chinook", "Chinook"], ["rescue_rotor", "Спасательный вертолёт"]]],
	["Интерфейс", [["pickup", "Пленный подобран"], ["rescue_pickup", "Пленный в вертолёте"],
			["upgrade", "Улучшение оружия"], ["extra_life", "Дополнительная жизнь"], ["warning", "Предупреждение о боссе"], ["pause", "Пауза"]]],
	["Окружение", [["ambient_sea", "Море"], ["ambient_jungle", "Джунгли"]]],
]
# The Mixer tab: the game's own gains (Level3DAudio's mix), in dB, for the
# mode picked on it. SOUND_GROUPS' sounds, with enemy_hit after the blast it
# is played under in classic, and the music's parts.
const MIX_EXTRA := {"blast": ["enemy_hit", "Удар под взрывом (enemy_hit)"]}
const MUSIC_NAMES := {
	"start.ogg": "Заставка перед высадкой", "stage0_intro.ogg": "Этап: вступление",
	"stage0_repeat.ogg": "Этап: петля", "boss_intro.ogg": "Босс: вступление",
	"boss_repeat.ogg": "Босс: петля",
}
const MIX_MIN_DB := -40.0
const MIX_MAX_DB := 12.0
const MIX_STEP_DB := 0.5
# Level3DSettings.Reach as the menu lists it, shortest first.
const REACH_ORDER := [Level3DSettings.Reach.CLASSIC, Level3DSettings.Reach.LONG, Level3DSettings.Reach.UNLIMITED]
const ACTION_NAMES := {
	"up": "Вперёд / вверх", "down": "Назад / вниз", "left": "Влево", "right": "Вправо",
	"gun": "Пулемёт", "rocket": "Ракета",
}

var settings: Level3DSettings
var changed: Callable        # after every change, with the menu still open
var resumed: Callable        # once the menu has closed
# `new_game.call(players)`: the run started again for one player or two (the
# preview's co-op); the preview closes the menu.
var new_game: Callable
# Started by the level editor's Play (--editor): leaving is going back to it,
# which is waiting for this process to end.
var from_editor := false

var _main_page: Control
var _settings_page: Control
var _tabs: TabContainer
var _camera: OptionButton
var _look: OptionButton
var _crt: CheckBox
var _resolution: OptionButton
var _driving: OptionButton
var _firing: OptionButton
var _reach: OptionButton
var _infinite_lives: CheckBox
var _wall_hack: CheckBox
var _bullet_hack: CheckBox
var _gun_rate: OptionButton
var _launcher_rate: OptionButton
var _hud: CheckBox
var _hud_score: CheckBox
var _hud_lives: CheckBox
var _hud_pows: CheckBox
var _hud_weapon: CheckBox
var _hud_modes: CheckBox
var _hud_pad_arrow: CheckBox
var _hud_help: CheckBox
var _hud_cheats: CheckBox
var _hud_crosshair: CheckBox
var _banner_stage: CheckBox
var _banner_warning: CheckBox
var _banner_mission: CheckBox
var _hud_corner: OptionButton
var _hud_scale: OptionButton
var _sound_mode: OptionButton
var _master_volume: HSlider
var _music_volume: HSlider
var _effects_volume: HSlider
var _enemy_fire: CheckBox
var _enemy_fire_volume: HSlider
var _gain_sliders := {}      # sound -> HSlider
var _gains_reset: Button
var _mixer_mode: OptionButton
var _mix_sliders := {}       # sound -> HSlider
var _music_sliders := {}     # music file -> HSlider
var _mix_status: Label
var _mix_save: Button
var _key_buttons := {}       # action -> Button
var _waiting := ""           # the action a key prompt is open for
var _continue: Button


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	for state in ["unchecked", "unchecked_disabled"]:
		theme.set_icon(state, "CheckBox", _box_icon(false))
	for state in ["checked", "checked_disabled"]:
		theme.set_icon(state, "CheckBox", _box_icon(true))
	theme.set_constant("h_separation", "CheckBox", 10)
	var root := Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	_main_page = _make_main_page()
	centre.add_child(_main_page)
	_settings_page = _make_settings_page()
	centre.add_child(_settings_page)


func is_open() -> bool:
	return visible


# With GameMode's pause sound, which its pause key plays both ways.
func open() -> void:
	visible = true
	get_tree().paused = true
	Level3DAudio.play("pause")
	_show_main()


func close() -> void:
	_waiting = ""
	visible = false
	# The stage's song again, if the Mixer tab put a part of another on.
	Level3DAudio.end_music_audition()
	get_tree().paused = false
	Level3DAudio.play("pause")
	if resumed.is_valid():
		resumed.call()


func _show_main() -> void:
	_waiting = ""
	_settings_page.visible = false
	_main_page.visible = true
	_continue.grab_focus()


func _show_settings() -> void:
	refresh()
	_main_page.visible = false
	_settings_page.visible = true
	_tabs.get_tab_bar().grab_focus()


# The widgets from `settings`, which the preview's own keys (Tab, V, M) change
# behind the menu's back.
func refresh() -> void:
	_camera.select(settings.camera)
	_look.select(settings.look)
	_crt.set_pressed_no_signal(settings.crt)
	_resolution.select(settings.resolution)
	_driving.select(settings.driving)
	_firing.select(settings.firing)
	_reach.select(REACH_ORDER.find(settings.reach))
	_infinite_lives.set_pressed_no_signal(settings.infinite_lives)
	_wall_hack.set_pressed_no_signal(settings.wall_hack)
	_bullet_hack.set_pressed_no_signal(settings.bullet_hack)
	_gun_rate.select(Level3DSettings.RATES.find(settings.gun_rate))
	_launcher_rate.select(Level3DSettings.RATES.find(settings.launcher_rate))
	_hud.set_pressed_no_signal(settings.hud)
	_hud_score.set_pressed_no_signal(settings.hud_score)
	_hud_lives.set_pressed_no_signal(settings.hud_lives)
	_hud_pows.set_pressed_no_signal(settings.hud_pows)
	_hud_weapon.set_pressed_no_signal(settings.hud_weapon)
	_hud_modes.set_pressed_no_signal(settings.hud_modes)
	_hud_pad_arrow.set_pressed_no_signal(settings.hud_pad_arrow)
	_hud_help.set_pressed_no_signal(settings.hud_help)
	_hud_cheats.set_pressed_no_signal(settings.hud_cheats)
	_hud_crosshair.set_pressed_no_signal(settings.hud_crosshair)
	_banner_stage.set_pressed_no_signal(settings.banner_stage)
	_banner_warning.set_pressed_no_signal(settings.banner_warning)
	_banner_mission.set_pressed_no_signal(settings.banner_mission)
	_hud_corner.select(settings.hud_corner)
	_hud_scale.select(Level3DSettings.HUD_SCALES.find(settings.hud_scale))
	_sound_mode.select(settings.sound_mode)
	_master_volume.set_value_no_signal(settings.master_volume * 100.0)
	_music_volume.set_value_no_signal(settings.music_volume * 100.0)
	_effects_volume.set_value_no_signal(settings.effects_volume * 100.0)
	_enemy_fire.set_pressed_no_signal(settings.enemy_fire)
	_enemy_fire_volume.set_value_no_signal(settings.enemy_fire_volume * 100.0)
	# The classic mode has no enemies' fire to switch: the original had none.
	var modern := settings.sound_mode == Level3DSettings.SoundMode.MODERN
	_enemy_fire.disabled = not modern
	_enemy_fire_volume.editable = modern and settings.enemy_fire
	for sound in _gain_sliders:
		var slider: HSlider = _gain_sliders[sound]
		slider.set_value_no_signal(float(settings.sound_gains.get(sound, 1.0)) * 100.0)
		slider.editable = modern
		_show_percent(slider)
	_gains_reset.disabled = not modern
	for slider in [_master_volume, _music_volume, _effects_volume, _enemy_fire_volume]:
		_show_percent(slider)
	_mixer_mode.select(settings.sound_mode)
	_refresh_mixer()
	# Greyed out, not hidden, with the HUD off: what it would show stays set.
	for widget in [_hud_score, _hud_lives, _hud_pows, _hud_weapon, _hud_modes, _hud_cheats, _hud_pad_arrow,
			_hud_help, _banner_stage, _banner_warning, _banner_mission, _hud_corner, _hud_scale]:
		widget.disabled = not settings.hud
	for action in _key_buttons:
		var button: Button = _key_buttons[action]
		button.text = "..." if action == _waiting else OS.get_keycode_string(settings.key(action))


func _changed() -> void:
	refresh()
	if changed.is_valid():
		changed.call()


# ----------------------------------------------------------------------------
# Pages

func _make_main_page() -> Control:
	var panel := PanelContainer.new()
	var box := _padded_box(panel, 16)
	box.custom_minimum_size = Vector2(360, 0)
	var title := Label.new()
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", FONT_SIZE + 8)
	box.add_child(title)
	_continue = _button(box, "Продолжить", close)
	_button(box, "Новая игра: 1 игрок", func(): new_game.call(1))
	_button(box, "Новая игра: 2 игрока", func(): new_game.call(2))
	_button(box, "Настройки", _show_settings)
	_button(box, "В редактор" if from_editor else "Выход", func(): get_tree().quit())
	return panel


func _make_settings_page() -> Control:
	var panel := PanelContainer.new()
	var box := _padded_box(panel, 12)
	box.custom_minimum_size = Vector2(760, 820)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_tabs)
	_tabs.add_child(_make_graphics_tab())
	_tabs.add_child(_make_interface_tab())
	_tabs.add_child(_make_sound_tab())
	_tabs.add_child(_make_mixer_tab())
	_tabs.add_child(_make_controls_tab())
	_tabs.add_child(_make_cheats_tab())
	_button(box, "Назад", _show_main)
	return panel


func _make_graphics_tab() -> Control:
	var tab := _tab("Графика")
	var grid := _grid(tab)
	_camera = _choice(grid, "Камера", ["Вид сверху", "Вид сверху под наклоном"],
			func(i: int): settings.camera = i)
	_look = _choice(grid, "Визуализация", ["Современный", "Пиксели"],
			func(i: int): settings.look = i)
	_resolution = _choice(grid, "Разрешение 3D", ["Как у экрана", "2048×1152 (как в игре)", "1920×1080", "1280×720"],
			func(i: int): settings.resolution = i)
	_crt = _check(tab, "ЭЛТ-монитор", func(on: bool): settings.crt = on)
	return tab.get_parent().get_parent()


func _make_interface_tab() -> Control:
	var tab := _tab("Интерфейс")
	_hud = _check(tab, "Показывать HUD", func(on: bool): settings.hud = on)
	tab.add_child(HSeparator.new())
	_heading(tab, "Что показывать")
	_hud_score = _check(tab, "Счёт", func(on: bool): settings.hud_score = on)
	_hud_lives = _check(tab, "Жизни", func(on: bool): settings.hud_lives = on)
	_hud_pows = _check(tab, "Пленные на борту", func(on: bool): settings.hud_pows = on)
	_hud_weapon = _check(tab, "Оружие", func(on: bool): settings.hud_weapon = on)
	_hud_modes = _check(tab, "Режимы езды и стрельбы", func(on: bool): settings.hud_modes = on)
	_note(tab, "Выключено: режим появляется на пару секунд, когда его меняют клавишами V и M.")
	_hud_cheats = _check(tab, "Активные читы", func(on: bool): settings.hud_cheats = on)
	_hud_pad_arrow = _check(tab, "Стрелка к вертолёту", func(on: bool): settings.hud_pad_arrow = on)
	_note(tab, "Пока на борту пленные, а вертолёт, который их заберёт, за краем экрана.")
	_hud_help = _check(tab, "Крики HELP", func(on: bool): settings.hud_help = on)
	_note(tab, "Над целыми зданиями, где сидят пленные, и над пленными, которых долго не подбирают.")
	tab.add_child(HSeparator.new())
	_heading(tab, "Надписи")
	_banner_stage = _check(tab, "Номер этапа при высадке", func(on: bool): settings.banner_stage = on)
	_banner_warning = _check(tab, "Предупреждение о боссе", func(on: bool): settings.banner_warning = on)
	_banner_mission = _check(tab, "Миссия выполнена и спасённые пленные",
			func(on: bool): settings.banner_mission = on)
	tab.add_child(HSeparator.new())
	_hud_crosshair = _check(tab, "Прицел вместо курсора", func(on: bool): settings.hud_crosshair = on)
	_note(tab, "В современном и комбинированном режимах стрельбы, где целятся мышью. Работает и без HUD.")
	tab.add_child(HSeparator.new())
	var layout := _grid(tab)
	_hud_corner = _choice(layout, "Положение", ["Сверху", "Снизу"],
			func(i: int): settings.hud_corner = i)
	_hud_scale = _choice(layout, "Размер",
			Level3DSettings.HUD_SCALES.map(func(s: float): return "%d%%" % roundi(s * 100.0)),
			func(i: int): settings.hud_scale = Level3DSettings.HUD_SCALES[i])
	return tab.get_parent().get_parent()


func _make_sound_tab() -> Control:
	var tab := _tab("Звук")
	var modes := _grid(tab)
	_sound_mode = _choice(modes, "Звук", ["Классический", "Новый"],
			func(i: int):
				settings.sound_mode = i
				_preview("pickup"))
	_note(tab, "Классический: звуки оригинальной игры, как в ней. "
			+ "Новый: объёмный звук, двигатели, окружение, выстрелы врагов и своя музыка.")
	tab.add_child(HSeparator.new())
	_heading(tab, "Громкость")
	var volumes := _grid(tab)
	_master_volume = _slider(volumes, "Общая", func(v: float): settings.master_volume = v)
	_music_volume = _slider(volumes, "Музыка", func(v: float): settings.music_volume = v)
	_effects_volume = _slider(volumes, "Эффекты",
			func(v: float):
				settings.effects_volume = v
				_preview("pickup"))
	tab.add_child(HSeparator.new())
	_heading(tab, "Выстрелы врагов")
	_enemy_fire = _check(tab, "Слышны выстрелы врагов",
			func(on: bool):
				settings.enemy_fire = on
				_preview("enemy_mg"))
	var enemy := _grid(tab)
	_enemy_fire_volume = _slider(enemy, "Громкость",
			func(v: float):
				settings.enemy_fire_volume = v
				_preview("enemy_mg"))
	_note(tab, "В оригинале враги стреляли беззвучно. Только в новом режиме.")
	tab.add_child(HSeparator.new())
	_heading(tab, "Каждый звук нового режима")
	_note(tab, "100% — громкость, под которую звук подобран. До 200% — громче. "
			+ "Звуки без своего файла играют звук оригинала, и ползунок действует и на него.")
	for group in SOUND_GROUPS:
		var title := Label.new()
		title.text = group[0]
		tab.add_child(title)
		var grid := _grid(tab)
		for pair in group[1]:
			var sound: String = pair[0]
			_gain_sliders[sound] = _slider(grid, "    " + pair[1], _gain_moved(sound),
					Level3DAudio.MAX_GAIN * 100.0)
	_gains_reset = Button.new()
	_gains_reset.text = "Все на 100%"
	_gains_reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	_gains_reset.pressed.connect(func():
		settings.sound_gains = {}
		_changed())
	tab.add_child(_gains_reset)
	return tab.get_parent().get_parent()


# A sound's slider: its gain into the settings, and the sound itself to hear
# it by -- not a loop, which is heard as it is, where it plays.
func _gain_moved(sound: String) -> Callable:
	return func(v: float):
		settings.sound_gains[sound] = v
		if not Level3DAudio.SOUNDS[sound].get("loop", false):
			_preview(sound)


# The game's mix, not the player's: every sound's and every music part's gain
# in dB, for the mode picked here (the same setting as the Sound tab's), heard
# as it is moved and written to Level3DAudio.MIX_PATH by Save. The player's
# own sliders on the Sound tab still act over it.
func _make_mixer_tab() -> Control:
	var tab := _tab("Микшер")
	var modes := _grid(tab)
	_mixer_mode = _choice(modes, "Режим", ["Классический", "Новый"],
			func(i: int): settings.sound_mode = i)
	_note(tab, "Громкость каждого звука и музыки в игре, в дБ, отдельно для каждого режима. "
			+ "▶ — послушать; звук играет и после того, как ползунок отпущен. "
			+ "Музыка играет по кругу, пока не нажать ■ или «Музыка уровня». "
			+ "«Сохранить» записывает всё в assets/sfx3d/mix.json. "
			+ "Ползунки вкладки «Звук» — настройки игрока — действуют поверх.")
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	tab.add_child(actions)
	_mix_save = _button(actions, "Сохранить", func():
		var err := Level3DAudio.save_mix()
		_refresh_mixer()
		if err != OK:
			_mix_status.text = "Не сохранено (%s): в собранной игре файлы проекта только для чтения." % error_string(err)
		else:
			_mix_status.text = "Сохранено в %s" % Level3DAudio.MIX_PATH)
	_button(actions, "Вернуть сохранённое", func():
		Level3DAudio.reload_mix()
		_refresh_mixer())
	_button(actions, "Музыка уровня", func():
		Level3DAudio.end_music_audition()
		_refresh_music_buttons())
	_mix_status = Label.new()
	_mix_status.add_theme_font_size_override("font_size", FONT_SIZE - 6)
	_mix_status.add_theme_color_override("font_color", ACCENT)
	tab.add_child(_mix_status)
	tab.add_child(HSeparator.new())
	_heading(tab, "Музыка")
	var music := _mix_grid(tab)
	music.set_meta("music", true)
	for file in Level3DAudio.music_files():
		_music_sliders[file] = _mix_row(music, "    " + MUSIC_NAMES.get(file, file),
				func(): _toggle_music(file),
				func(db: float): Level3DAudio.set_music_db(file, db, _mixer_audio_mode()))
		# Let go of the slider, the part is heard again rather than stopped.
		var slider: HSlider = _music_sliders[file]
		slider.drag_ended.connect(func(value_changed: bool):
			if value_changed and Level3DAudio.auditioned_music() != file:
				Level3DAudio.audition_music(file)
				_refresh_music_buttons())
	for group in SOUND_GROUPS:
		tab.add_child(HSeparator.new())
		_heading(tab, group[0])
		var grid := _mix_grid(tab)
		var rows: Array = []
		for pair in group[1]:
			rows.append(pair)
			if MIX_EXTRA.has(pair[0]):
				rows.append(MIX_EXTRA[pair[0]])
		for pair in rows:
			var sound: String = pair[0]
			_mix_sliders[sound] = _mix_row(grid, "    " + pair[1],
					func(): Level3DAudio.audition(sound),
					func(db: float): Level3DAudio.set_mix_db(sound, db, _mixer_audio_mode()))
	return tab.get_parent().get_parent()


# The Mixer tab's mode as Level3DAudio has it: the setting's, which the
# preview hands on to Level3DAudio only after the menu's refresh.
func _mixer_audio_mode() -> int:
	return Level3DAudio.Mode.CLASSIC if settings.sound_mode == Level3DSettings.SoundMode.CLASSIC \
			else Level3DAudio.Mode.MODERN


# A music part's ▶: on, it plays the part alone, looped, and turns to ■;
# again, it gives the stage's song back from where it was.
func _toggle_music(file: String) -> void:
	if Level3DAudio.auditioned_music() == file:
		Level3DAudio.end_music_audition()
	else:
		Level3DAudio.audition_music(file)
	_refresh_music_buttons()


func _refresh_music_buttons() -> void:
	var on := Level3DAudio.auditioned_music()
	for file in _music_sliders:
		(_music_sliders[file].get_meta("play") as Button).text = "■" if file == on else "▶"


func _refresh_mixer() -> void:
	var m := _mixer_audio_mode()
	for sound in _mix_sliders:
		_show_db(_mix_sliders[sound], Level3DAudio.mix_db(sound, m), Level3DAudio.saved_mix_db(sound, m))
	for file in _music_sliders:
		_show_db(_music_sliders[file], Level3DAudio.music_db(file, m), Level3DAudio.saved_music_db(file, m))
	_mix_update_status()
	_refresh_music_buttons()


func _mix_update_status() -> void:
	var changed_now := Level3DAudio.is_mix_changed()
	_mix_save.disabled = not changed_now
	if changed_now:
		_mix_status.text = "Есть несохранённые изменения"
	elif _mix_status.text == "Есть несохранённые изменения":
		_mix_status.text = ""


func _mix_grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	return grid


# A row of the Mixer tab: the name, a button to hear it, the gain in dB, and
# the gain in figures, in ACCENT while it differs from the file's.
func _mix_row(grid: GridContainer, text: String, audition: Callable, moved: Callable) -> HSlider:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var play := Button.new()
	play.text = "▶"
	play.custom_minimum_size = Vector2(44, 0)
	play.pressed.connect(audition)
	grid.add_child(play)
	var slider := HSlider.new()
	slider.min_value = MIX_MIN_DB
	slider.max_value = MIX_MAX_DB
	slider.step = MIX_STEP_DB
	slider.custom_minimum_size = Vector2(220, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size = Vector2(110, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(value)
	slider.set_meta("db", value)
	slider.set_meta("play", play)
	slider.value_changed.connect(func(db: float):
		moved.call(db)
		_show_db(slider, db, float(slider.get_meta("saved", db)))
		_mix_update_status())
	# A sound is heard again when the slider is let go; a music part's own
	# row sees to it (_make_mixer_tab), since its ▶ is a switch.
	if not grid.has_meta("music"):
		slider.drag_ended.connect(func(value_changed: bool):
			if value_changed:
				audition.call())
	return slider


func _show_db(slider: HSlider, db: float, saved: float) -> void:
	slider.set_meta("saved", saved)
	slider.set_value_no_signal(db)
	var label: Label = slider.get_meta("db")
	label.text = "%+.1f дБ" % db
	if is_equal_approx(db, saved):
		label.remove_theme_color_override("font_color")
	else:
		label.add_theme_color_override("font_color", ACCENT)


func _make_controls_tab() -> Control:
	var tab := _tab("Управление")
	# The modes first: they are changed far more often than the keys.
	var modes := _grid(tab)
	_driving = _choice(modes, "Режим езды", ["Классический", "Современный"],
			func(i: int): settings.driving = i)
	_note(tab, "Классический: джип едет туда, куда нажато направление, как в игре. "
			+ "Современный: газ и руль, как у настоящей машины.")
	var firing := _grid(tab)
	_firing = _choice(firing, "Режим стрельбы", ["Классический", "Современный", "Комбинированный"],
			func(i: int): settings.firing = i)
	_note(tab, "Классический: пулемёт вперёд, ракеты по направлению джипа. "
			+ "Современный: всё по курсору. Комбинированный: пулемёт всегда вверх по экрану, ракеты по курсору.")
	var reach := _grid(tab)
	_reach = _choice(reach, "Дальность стрельбы", ["Классическая", "Увеличенная", "Не ограничена"],
			func(i: int): settings.reach = REACH_ORDER[i])
	_note(tab, "При любом режиме езды и стрельбы. Классическая: как в игре, около 5 м. "
			+ "Увеличенная: пулемёт 12 м, ракеты 16 м. "
			+ "Не ограничена: летят, пока во что-нибудь не попадут. "
			+ "Наведённые курсором пули и ракеты останавливаются у курсора, но не дальше дальности.")
	tab.add_child(HSeparator.new())
	_heading(tab, "Настройка управления")
	var keys := _grid(tab)
	for action in Level3DSettings.ACTIONS:
		var label := Label.new()
		label.text = ACTION_NAMES[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keys.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 0)
		button.pressed.connect(func(): _prompt(action))
		keys.add_child(button)
		_key_buttons[action] = button
	var defaults := Button.new()
	defaults.text = "Клавиши по умолчанию"
	defaults.size_flags_horizontal = Control.SIZE_SHRINK_END
	defaults.pressed.connect(func():
		_waiting = ""
		settings.reset_keys()
		_changed())
	tab.add_child(defaults)
	_note(tab, "Второй игрок: клавиши и геймпад второго игрока из 2D-игры, по умолчанию стрелки, "
			+ "правый Alt (пулемёт) и правый Ctrl (ракеты). Переназначаются в игре: "
			+ "Options → 2p input. Стреляет всегда классически.")
	return tab.get_parent().get_parent()


func _make_cheats_tab() -> Control:
	var tab := _tab("Читы")
	_infinite_lives = _check(tab, "Бесконечные жизни", func(on: bool): settings.infinite_lives = on)
	_wall_hack = _check(tab, "Wall hack: езда сквозь стены", func(on: bool): settings.wall_hack = on)
	_bullet_hack = _check(tab, "Bullet hack: неуязвимость к снарядам",
			func(on: bool): settings.bullet_hack = on)
	_note(tab, "Таран пушки или танка по-прежнему убивает.")
	tab.add_child(HSeparator.new())
	var rates := _grid(tab)
	var names := Level3DSettings.RATES.map(func(r: float): return "×1 (как в игре)" if r == 1.0 else "×%s" % String.num(r).replace(".", ","))
	_gun_rate = _choice(rates, "Скорострельность пулемёта", names,
			func(i: int): settings.gun_rate = Level3DSettings.RATES[i])
	_launcher_rate = _choice(rates, "Скорострельность пусковой", names,
			func(i: int): settings.launcher_rate = Level3DSettings.RATES[i])
	return tab.get_parent().get_parent()


# ----------------------------------------------------------------------------
# Key prompts

func _prompt(action: String) -> void:
	_waiting = action
	refresh()


func _input(event: InputEvent) -> void:
	if not visible or _waiting == "":
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	var button: Button = _key_buttons[_waiting]
	if key.keycode != KEY_ESCAPE:
		var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
		settings.bind(_waiting, code)
	_waiting = ""
	_changed()
	button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if _settings_page.visible:
		_show_main()
	else:
		close()


# ----------------------------------------------------------------------------
# Widgets

func _padded_box(panel: PanelContainer, gap: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	margin.add_child(box)
	return box


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


# A tab's page: a scrolling column under the tab's name. Returns the column;
# the tab itself is its grandparent.
func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	return column


func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	return grid


func _heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ACCENT)
	parent.add_child(label)


func _note(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(640, 0)
	label.add_theme_font_size_override("font_size", FONT_SIZE - 6)
	label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	parent.add_child(label)


func _choice(grid: GridContainer, text: String, items: Array, picked: Callable) -> OptionButton:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(340, 0)
	for item in items:
		option.add_item(item)
	option.item_selected.connect(func(i: int):
		picked.call(i)
		_changed())
	grid.add_child(option)
	return option


# A volume, 0 to `top` % on the slider and 0 to top / 100 to `moved`, with
# the percentage beside it. A row of the grid: the label, then the two.
func _slider(grid: GridContainer, text: String, moved: Callable, top := 100.0) -> HSlider:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = top
	slider.step = 5.0
	slider.custom_minimum_size = Vector2(260, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := Label.new()
	value.name = "Percent"
	value.custom_minimum_size = Vector2(68, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	slider.set_meta("percent", value)
	slider.value_changed.connect(func(v: float):
		moved.call(v / 100.0)
		_changed())
	grid.add_child(row)
	return slider


# A sound to hear a change by, once the change is on the buses: the menu's
# callbacks run before _changed hands it to the preview.
func _preview(sound: String) -> void:
	(func(): Level3DAudio.play(sound)).call_deferred()


func _show_percent(slider: HSlider) -> void:
	(slider.get_meta("percent") as Label).text = "%d%%" % roundi(slider.value)


func _check(parent: Control, text: String, toggled: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.toggled.connect(func(on: bool):
		toggled.call(on)
		_changed())
	parent.add_child(check)
	return check


# A check box's icon, drawn rather than the default theme's, which is black on
# the panel's near black when it is not ticked: a light frame either way,
# filled with ACCENT and ticked in the panel's dark when it is.
func _box_icon(ticked: bool) -> ImageTexture:
	var side := ICON_SIZE * ICON_OVERSAMPLE
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var frame := Color(0.85, 0.85, 0.85)
	var dark := Color(0.12, 0.1, 0.08)
	var line := 2.0 * ICON_OVERSAMPLE        # the frame's and the tick's width
	var inset := 1.5 * ICON_OVERSAMPLE
	var tick: Array[Vector2] = [Vector2(0.24, 0.52), Vector2(0.43, 0.7), Vector2(0.77, 0.3)]
	for y in side:
		for x in side:
			var p := Vector2(x + 0.5, y + 0.5)
			# How far inside the frame's outer edge, and so what covers it.
			var edge := minf(minf(p.x, p.y), minf(side - p.x, side - p.y)) - inset
			var outside := clampf(0.5 - edge, 0.0, 1.0)
			var on_frame := clampf(line - edge + 0.5, 0.0, 1.0) * (1.0 - outside)
			var colour := Color(0, 0, 0, 0)
			if ticked:
				colour = ACCENT
				colour.a = 1.0 - outside
				var d := minf(_to_segment(p, tick[0] * side, tick[1] * side),
						_to_segment(p, tick[1] * side, tick[2] * side))
				colour = colour.lerp(dark, clampf(line * 0.75 - d + 0.5, 0.0, 1.0) * colour.a)
			else:
				colour = Color(frame, on_frame)
			image.set_pixel(x, y, colour)
	var texture := ImageTexture.create_from_image(image)
	texture.set_size_override(Vector2i(ICON_SIZE, ICON_SIZE))
	return texture


static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
