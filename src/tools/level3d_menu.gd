# The 3D preview's Escape menu: continue, settings, quit, over the stage
# frozen by pausing the tree. The settings are four tabs of
# Level3DSettings -- graphics (the camera and the look), interface (what the
# HUD shows, where and how big), controls (the keys, how the BTR drives and
# how it fires) and cheats -- and every change is handed
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
const ACTION_NAMES := {
	"up": "Вперёд / вверх", "down": "Назад / вниз", "left": "Влево", "right": "Вправо",
	"gun": "Пулемёт", "rocket": "Ракета",
}

var settings: Level3DSettings
var changed: Callable        # after every change, with the menu still open
var resumed: Callable        # once the menu has closed

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
var _hud_crosshair: CheckBox
var _hud_corner: OptionButton
var _hud_scale: OptionButton
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


func open() -> void:
	visible = true
	get_tree().paused = true
	_show_main()


func close() -> void:
	_waiting = ""
	visible = false
	get_tree().paused = false
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
	_reach.select(settings.reach)
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
	_hud_crosshair.set_pressed_no_signal(settings.hud_crosshair)
	_hud_corner.select(settings.hud_corner)
	_hud_scale.select(Level3DSettings.HUD_SCALES.find(settings.hud_scale))
	# Greyed out, not hidden, with the HUD off: what it would show stays set.
	for widget in [_hud_score, _hud_lives, _hud_pows, _hud_weapon, _hud_modes, _hud_pad_arrow,
			_hud_corner, _hud_scale]:
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
	_button(box, "Настройки", _show_settings)
	_button(box, "Выход", func(): get_tree().quit())
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
	_hud_pad_arrow = _check(tab, "Стрелка к вертолёту", func(on: bool): settings.hud_pad_arrow = on)
	_note(tab, "Пока на борту пленные, а вертолёт, который их заберёт, за краем экрана.")
	tab.add_child(HSeparator.new())
	_hud_crosshair = _check(tab, "Прицел вместо курсора", func(on: bool): settings.hud_crosshair = on)
	_note(tab, "В современном и комбинированном режимах стрельбы, где целятся мышью. Работает и без HUD.")
	tab.add_child(HSeparator.new())
	var layout := _grid(tab)
	_hud_corner = _choice(layout, "Положение", ["Сверху слева", "Снизу слева"],
			func(i: int): settings.hud_corner = i)
	_hud_scale = _choice(layout, "Размер",
			Level3DSettings.HUD_SCALES.map(func(s: float): return "%d%%" % roundi(s * 100.0)),
			func(i: int): settings.hud_scale = Level3DSettings.HUD_SCALES[i])
	return tab.get_parent().get_parent()


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
	_reach = _choice(reach, "Дальность стрельбы", ["Классическая", "Не ограничена"],
			func(i: int): settings.reach = i)
	_note(tab, "Классическая: как в игре, пули и ракеты летят недалеко. "
			+ "Не ограничена: летят, пока во что-нибудь не попадут; ракета, наведённая курсором, взрывается у курсора.")
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
