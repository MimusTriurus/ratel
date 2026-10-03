# The 3D preview's title screen, the 2D game's (IntroMode's title and its
# Menu) over the stage: the splash where the title art was, the menus'
# reticle where Menu's jeep icon was (Level3DReticle), the same layout in the
# 1024x960 frame centred in the 2048x1152 one. Its entries are the preview's own: a
# game for one player or two (the 2D game's "1 player" / "2 players"), the
# mode -- 8-bit or modern, the Escape menu's Game tab (Level3DSettings.Preset),
# here too since it is what a game is played as --, the difficulty the 2D
# game picks under options, the Escape menu's settings, and quit. Written in the HUD's font (Level3DFont), so that it follows the
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
# change the mode or the difficulty; the mouse picks an entry by aiming the reticle at it.
class_name Level3DTitle
extends CanvasLayer

enum Entry { ONE_PLAYER, TWO_PLAYERS, MODE, DIFFICULTY, SETTINGS, QUIT }
# The mode's names, by Level3DSettings.Preset; custom is a mode changed on the
# settings' own tabs, which picking the mode here leaves.
const MODE_NAMES := ["8-bit", "modern", "custom"]

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
# The reticle (Level3DReticle) is in place of the 2D game's jeep icon, which
# was the one sprite left on a screen drawn otherwise in the splash's dark and
# the sun's colours; the keys glide it to before the entry they pick.
# The entries: the one picked in the sun's yellow, the others a dim copper.
const PICKED_TINT := Color(1.0, 0.83, 0.42)
const OTHER_TINT := Color(0.55, 0.36, 0.27)
# A game picked over a splash that drives its jeeps off (Level3DSplash3D.
# launch): the menu's keys held off while they go, for as long as the
# splash's launch says -- or, when it cannot say yet, until its fade_after
# can (Level3DSplashLanding's Chinook lifts off once the stage is built) --
# before the title fades to black over LAUNCH_FADE, and then the run; any key
# or click fades at once. Over the picture the run starts at once, as it
# always did. Either way not before the stage under the title is built
# (game_ready): until then the title stays, black if it has faded.
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
var _splash: Control         # Level3DSplash, or Level3DSplash3D under --splash-3d
var _veil: ColorRect         # the fade to black over the launch
var _launching := false
var _launch: Tween           # the hold and the fade
var _waiting := 0            # players of a game whose fade the splash cannot time yet
var _game_ready := false     # the stage under the title is built (game_ready)
var _reticle: Level3DReticle
var _text: Control           # the entries, in the font's filter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
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
	_text = Control.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.draw.connect(_draw_text)
	add_child(_text)
	_reticle = Level3DReticle.new()
	add_child(_reticle)
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
	_waiting = 0
	if _launch != null:
		_launch.kill()
		_launch = null
	_veil.color.a = 0.0
	if _splash != null and _splash.has_method("reset_launch"):
		_splash.reset_launch()
	_reticle.park()
	_reticle.aim(_slot, false)
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


# Whether the system's pointer is hidden, the reticle in its place: while the
# title is up and the settings are not over it -- they have a reticle of
# their own (Level3DMenu.pointer_hidden). Level3DCrosshair, which owns the
# mouse mode, asks this too.
func pointer_hidden() -> bool:
	return visible and not (settings_open.is_valid() and settings_open.call())


# The stage under the title is built, and a game can start (Level3DPreview's
# _ready builds it under the title); the splash is told, for a Chinook that
# waits for it to lift off.
func game_ready() -> void:
	_game_ready = true
	if _splash != null and _splash.has_method("game_ready"):
		_splash.game_ready()


func _entries() -> Array[String]:
	return ["1 player", "2 players", "mode: " + MODE_NAMES[settings.preset()],
			"difficulty: " + ("hard" if settings.hard else "normal"), "settings", "quit"]


func _process(delta: float) -> void:
	if _waiting > 0 and _launch == null:
		var after: float = _splash.call("fade_after")
		if not is_inf(after):
			var count := _waiting
			_waiting = 0
			_fade_out(count, after)
	if not visible:
		return
	_reticle.shown = pointer_hidden()
	# Until the HUD's crosshair, which owns the mouse mode, is made under the
	# title (Level3DPreview._ready), nobody else hides the pointer; and the
	# settings over it hide it themselves.
	if pointer_hidden() and Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


# Before the entry picked, where Menu's icon stood.
func _slot() -> Vector2:
	return FRAME + MENU_AT + Vector2(ICON_X, 16.0 + _selected * ROW)


func _select(index: int) -> void:
	index = clampi(index, 0, Entry.size() - 1)
	if index == _selected:
		return
	_selected = index
	_reticle.aim(_slot)
	_text.queue_redraw()
	_tell_splash()


func _pick() -> void:
	_reticle.fire()
	match _selected:
		Entry.ONE_PLAYER, Entry.TWO_PLAYERS:
			var count := _selected + 1
			if _splash != null and _splash.has_method("launch"):
				_launching = true
				_fade_out(count, _splash.call("launch", count))
			else:
				_launching = true
				_begin(count)
		Entry.MODE:
			_toggle_mode()
		Entry.DIFFICULTY:
			_toggle_difficulty()
		Entry.SETTINGS:
			open_settings.call()
		Entry.QUIT:
			get_tree().quit()


# The title fading out over the launch after `hold` seconds, and the run; an
# infinite hold waits for the splash to say (_process).
func _fade_out(count: int, hold: float) -> void:
	if _launch != null:
		_launch.kill()
		_launch = null
	if is_inf(hold):
		_waiting = count
		return
	_launch = create_tween()
	_launch.tween_interval(hold)
	_launch.tween_property(_veil, "color:a", 1.0, LAUNCH_FADE * (1.0 - _veil.color.a))
	_launch.tween_callback(func():
		_launch = null
		_begin(count))


# The run, once the stage is built.
func _begin(count: int) -> void:
	while not _game_ready:
		await get_tree().process_frame
	close()
	_launching = false
	_veil.color.a = 0.0
	start.call(count)


# 8-bit and modern by turns, custom going to modern; the settings saved and
# applied, the sound, the font and the look with them.
func _toggle_mode() -> void:
	var to := Level3DSettings.Preset.EIGHT_BIT if settings.preset() == Level3DSettings.Preset.MODERN \
			else Level3DSettings.Preset.MODERN
	settings.apply_preset(to)
	if changed.is_valid():
		changed.call()
	_redraw()


func _toggle_difficulty() -> void:
	settings.hard = not settings.hard
	if changed.is_valid():
		changed.call()
	_redraw()
	_tell_splash()


func _redraw() -> void:
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
		if pressed and (_launch != null or _waiting > 0) and _veil.color.a == 0.0:
			_waiting = 0
			_fade_out(_selected + 1, 0.0)
			get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var code := key.keycode
		if code in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] \
				or code in ["up", "down", "left", "right", "gun"].map(settings.key):
			_reticle.keys()
		if code in [KEY_UP, settings.key("up")]:
			_select(_selected - 1)
		elif code in [KEY_DOWN, settings.key("down")]:
			_select(_selected + 1)
		elif code in [KEY_LEFT, KEY_RIGHT, settings.key("left"), settings.key("right")]:
			if _selected == Entry.DIFFICULTY:
				_toggle_difficulty()
			elif _selected == Entry.MODE:
				_toggle_mode()
		elif code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, settings.key("gun")]:
			_pick()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var at := _entry_at()
		if _reticle.mouse_has_it() and at >= 0:
			_select(at)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var at := _entry_at()
		if at >= 0:
			_select(at)
			_pick()
			get_viewport().set_input_as_handled()


# The entry under the mouse, or -1: the row the text is on, from where the
# reticle stands before it to the end of the longest entry.
func _entry_at() -> int:
	var p := _text.get_local_mouse_position() - FRAME - MENU_AT
	if p.x < ICON_X - 48 or p.x > 640:
		return -1
	var row := floori((p.y + 16.0) / ROW)
	return row if row >= 0 and row < Entry.size() else -1


func _draw_text() -> void:
	var entries := _entries()
	for i in entries.size():
		Level3DFont.draw(_text, entries[i], FRAME.x + MENU_AT.x, FRAME.y + MENU_AT.y + i * ROW, GLYPH,
				Level3DFont.WHITE, PICKED_TINT if i == _selected else OTHER_TINT)
