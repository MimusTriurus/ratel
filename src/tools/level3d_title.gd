# The 3D preview's title screen, the 2D game's (IntroMode's title and its
# Menu) over the stage: the splash where the title art was, the jeep sliding
# between the entries as Menu's icon does, the same layout in the 1024x960
# frame centred in the 2048x1152 one. Its entries are the preview's own: a
# game for one player or two (the 2D game's "1 player" / "2 players"), the
# difficulty the 2D game picks under options, the Escape menu's settings,
# and quit. Written in the HUD's font (Level3DFont), so that it follows the
# settings as the HUD does.
#
# The preview shows it at the start, and from the Escape menu's "Main menu",
# with the tree paused under it and the stage hidden by its black; a game
# picked on it starts the run again from the Chinook (Level3DPreview.
# _start_game). Not shown for a --shot, or when the level editor's Play
# started the preview, which is there to try the level out.
#
# Keys as on the 2D game's menus: up and down (the arrows, and the keys
# bound to the BTR's), Enter, Space or the gun to pick, and left and right to
# change the difficulty; the mouse picks an entry by pointing at it.
class_name Level3DTitle
extends CanvasLayer

enum Entry { ONE_PLAYER, TWO_PLAYERS, DIFFICULTY, SETTINGS, QUIT }

# Where IntroMode draws them in its 1024x960 frame (title at 128,192, 25x8
# tiles of 32 px, Menu at
# 416,608, an entry each 64 px, the icon 72 px to the left of the text and
# 16 px down), and where that frame is in the 2048x1152 one.
const FRAME := Vector2(512, 96)
const TITLE_AT := Vector2(128, 192)
const TITLE_SIZE := Vector2(800, 256)
const MENU_AT := Vector2(416, 608)
const ROW := 64
const ICON_X := -72
const GLYPH := 32.0
# Menu's: the icon speeds up over the first half of the way and slows over the
# second, SELECT_TIME frames of the 2D game's 100 Hz in all.
const SELECT_TIME := 0.08
# A game picked over a splash that drives its jeeps off (Level3DSplash3D.
# launch): the menu's keys held off while they go, for as long as the
# splash's launch says, before the title fades to black over LAUNCH_FADE, and
# then the run; any key or click fades at once. Over the picture the run
# starts at once, as it always did.
const LAUNCH_FADE := 0.5

var settings: Level3DSettings
# `start.call(players)`: a game for one player or two, at settings.hard.
var start: Callable
# `open_settings.call()`: the Escape menu's settings over the title, coming
# back here when they are left (Level3DMenu.open_settings); `settings_open`
# says whether they are, and have the keys.
var open_settings: Callable
var settings_open: Callable
# `changed.call()`: settings.hard changed, to be saved.
var changed: Callable

var _selected := 0
var _icon_y := 16.0
var _from_y := 16.0
var _moving := 1.0           # 0 to 1 of the icon's way, 1 when it stands
var _jeep: Spr
var _splash: Control         # Level3DSplash, or Level3DSplash3D under --splash-3d
var _veil: ColorRect         # the fade to black over the launch
var _launching := false
var _launch: Tween           # the hold and the fade
var _art: Control            # the jeep, nearest
var _text: Control           # the entries, in the font's filter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_jeep = SpriteBank.new(Main.SPRITES).get_sprite("player-green-0.png")
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	# In place of the title art (level3d_splash.gd): as wide as it, in the
	# picture's own proportions rather than its, centred on where it was.
	# --splash-3d puts the scene there instead, a prototype
	# (level3d_splash3d.gd), and --splash-landing the scene with the Chinook
	# (level3d_splash_landing.gd).
	var splash: Control
	if OS.get_cmdline_user_args().has("--splash-landing"):
		splash = Level3DSplashLanding.new()
	elif OS.get_cmdline_user_args().has("--splash-3d"):
		splash = Level3DSplash3D.new()
	else:
		splash = Level3DSplash.new()
	splash.place(FRAME + TITLE_AT + TITLE_SIZE * 0.5, TITLE_SIZE.x)
	add_child(splash)
	_splash = splash
	_art = Control.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.draw.connect(_draw_art)
	add_child(_art)
	_text = Control.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.draw.connect(_draw_text)
	add_child(_text)
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_launching = false
	if _launch != null:
		_launch.kill()
		_launch = null
	_veil.color.a = 0.0
	if _splash != null and _splash.has_method("reset_launch"):
		_splash.reset_launch()
	_place_icon()
	_redraw()
	_tell_splash()


# The splash's jeeps follow the menu (Level3DSplash3D.show_menu): one jeep's
# lamps on for "1 player", both for "2 players", and the difficulty. A splash
# without show_menu, the picture, ignores it.
func _tell_splash() -> void:
	if _splash != null and _splash.has_method("show_menu"):
		var lit := 1 if _selected == Entry.ONE_PLAYER else (2 if _selected == Entry.TWO_PLAYERS else 0)
		_splash.show_menu(lit, settings.hard)


func close() -> void:
	visible = false


func _entries() -> Array[String]:
	return ["1 player", "2 players", "difficulty: " + ("hard" if settings.hard else "normal"),
			"settings", "quit"]


func _process(delta: float) -> void:
	if not visible or _moving >= 1.0:
		return
	_moving = minf(_moving + delta / SELECT_TIME, 1.0)
	var t := _moving
	var eased := 2.0 * t * t if t < 0.5 else 1.0 - 2.0 * (1.0 - t) * (1.0 - t)
	_icon_y = lerpf(_from_y, _target_y(), eased)
	_art.queue_redraw()


func _target_y() -> float:
	return 16.0 + _selected * ROW


func _place_icon() -> void:
	_moving = 1.0
	_icon_y = _target_y()


func _select(index: int) -> void:
	index = clampi(index, 0, Entry.size() - 1)
	if index == _selected:
		return
	_selected = index
	_from_y = _icon_y
	_moving = 0.0
	_tell_splash()


func _pick() -> void:
	match _selected:
		Entry.ONE_PLAYER, Entry.TWO_PLAYERS:
			var count := _selected + 1
			if _splash != null and _splash.has_method("launch"):
				_launching = true
				_fade_out(count, _splash.call("launch", count))
			else:
				close()
				start.call(count)
		Entry.DIFFICULTY:
			_toggle_difficulty()
		Entry.SETTINGS:
			open_settings.call()
		Entry.QUIT:
			get_tree().quit()


# The title fading out over the launch after `hold` seconds, and the run.
func _fade_out(count: int, hold: float) -> void:
	if _launch != null:
		_launch.kill()
	_launch = create_tween()
	_launch.tween_interval(hold)
	_launch.tween_property(_veil, "color:a", 1.0, LAUNCH_FADE * (1.0 - _veil.color.a))
	_launch.tween_callback(func():
		_launch = null
		close()
		_launching = false
		_veil.color.a = 0.0
		start.call(count))


func _toggle_difficulty() -> void:
	settings.hard = not settings.hard
	if changed.is_valid():
		changed.call()
	_redraw()
	_tell_splash()


func _redraw() -> void:
	_art.queue_redraw()
	_text.queue_redraw()
	_text.texture_filter = Level3DFont.filter()


func _input(event: InputEvent) -> void:
	# The settings over the title have the keys while they are open; while
	# the jeeps drive off, a key or a click only hurries the fade on.
	if not visible or settings_open.is_valid() and settings_open.call():
		return
	if _launching:
		var pressed: bool = event is InputEventKey and event.pressed and not event.echo \
				or event is InputEventMouseButton and event.pressed
		if pressed and _launch != null and _veil.color.a == 0.0:
			_fade_out(_selected + 1, 0.0)
			get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var code := key.keycode
		if code in [KEY_UP, settings.key("up")]:
			_select(_selected - 1)
		elif code in [KEY_DOWN, settings.key("down")]:
			_select(_selected + 1)
		elif code in [KEY_LEFT, KEY_RIGHT, settings.key("left"), settings.key("right")]:
			if _selected == Entry.DIFFICULTY:
				_toggle_difficulty()
		elif code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, settings.key("gun")]:
			_pick()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var at := _entry_at()
		if at >= 0:
			_select(at)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var at := _entry_at()
		if at >= 0:
			_select(at)
			_place_icon()
			_pick()
			get_viewport().set_input_as_handled()


# The entry under the mouse, or -1: the row the text is on, from where the
# icon would be to the end of the longest entry.
func _entry_at() -> int:
	var p := _text.get_local_mouse_position() - FRAME - MENU_AT
	if p.x < ICON_X - 48 or p.x > 640:
		return -1
	var row := floori((p.y + 16.0) / ROW)
	return row if row >= 0 and row < Entry.size() else -1


func _draw_art() -> void:
	if _jeep != null:
		var centre := FRAME + MENU_AT + Vector2(ICON_X, _icon_y)
		_art.draw_texture_rect_region(_jeep.tex, Rect2(centre - Vector2(_jeep.w, _jeep.h) * 0.5,
				Vector2(_jeep.w, _jeep.h)), _jeep.region)


func _draw_text() -> void:
	var entries := _entries()
	for i in entries.size():
		Level3DFont.draw(_text, entries[i], FRAME.x + MENU_AT.x, FRAME.y + MENU_AT.y + i * ROW, GLYPH,
				Level3DFont.GRAY)
