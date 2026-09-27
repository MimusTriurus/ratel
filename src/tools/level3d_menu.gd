# The 3D preview's Escape menu: continue, settings, quit, over the stage
# frozen by pausing the tree. The settings are three tabs of
# Level3DSettings -- graphics (the camera and the look), controls (the keys,
# how the BTR drives and how it fires) and cheats -- and every change is handed
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
const ACTION_NAMES := {
	"up": "Вперёд / вверх", "down": "Назад / вниз", "left": "Влево", "right": "Вправо",
	"gun": "Пулемёт", "rocket": "Ракета", "turret_left": "Башня влево",
	"turret_right": "Башня вправо",
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
var _driving: OptionButton
var _firing: OptionButton
var _reach: OptionButton
var _infinite_lives: CheckBox
var _wall_hack: CheckBox
var _bullet_hack: CheckBox
var _key_buttons := {}       # action -> Button
var _waiting := ""           # the action a key prompt is open for
var _continue: Button


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
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
	_driving.select(settings.driving)
	_firing.select(settings.firing)
	_reach.select(settings.reach)
	_infinite_lives.set_pressed_no_signal(settings.infinite_lives)
	_wall_hack.set_pressed_no_signal(settings.wall_hack)
	_bullet_hack.set_pressed_no_signal(settings.bullet_hack)
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
	box.custom_minimum_size = Vector2(760, 620)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_tabs)
	_tabs.add_child(_make_graphics_tab())
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
	_crt = _check(tab, "ЭЛТ-монитор", func(on: bool): settings.crt = on)
	return tab.get_parent().get_parent()


func _make_controls_tab() -> Control:
	var tab := _tab("Управление")
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
	tab.add_child(HSeparator.new())
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
	return tab.get_parent().get_parent()


func _make_cheats_tab() -> Control:
	var tab := _tab("Читы")
	_infinite_lives = _check(tab, "Бесконечные жизни", func(on: bool): settings.infinite_lives = on)
	_wall_hack = _check(tab, "Wall hack: езда сквозь стены", func(on: bool): settings.wall_hack = on)
	_bullet_hack = _check(tab, "Bullet hack: неуязвимость к снарядам",
			func(on: bool): settings.bullet_hack = on)
	_note(tab, "Таран пушки или танка по-прежнему убивает.")
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
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
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
