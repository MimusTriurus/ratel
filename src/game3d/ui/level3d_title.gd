# The 3D preview's title screen, the 2D game's (IntroMode's title and its
# Menu) over the stage: the splash, the scene with the sun and the jeeps, in
# the middle of the screen, the game's name over it (Level3DLogo) and the
# menu under it, the entry picked marked by a ▶ before it (Level3DSelection)
# where Menu's jeep icon stood. Its entries are the preview's own: a game for
# one player or two (the 2D game's "1 player" / "2 players"), the Escape
# menu's settings, and quit. Written in the HUD's font (Level3DFont), so that
# it follows the settings as the HUD does.
#
# The style (8-bit or modern) and the difficulty were entries here too, and
# are on the settings' Game tab (Level3DMenu) now: the scene took the room.
# It had stood where the 2D game's title art did, in the original's 1024x960
# frame, high on the screen over a menu six entries long.
#
# The preview shows it at the start, and from the Escape menu's "Main menu",
# with the tree paused under it and the stage hidden by its black; a game
# picked on it starts the run again from the Chinook (Level3DPreview.
# _start_game). Not shown for a --shot, or when the level editor's Play
# started the preview, which is there to try the level out.
#
# Keys as on the 2D game's menus: up and down (the arrows, and the keys
# bound to the BTR's), Enter, Space or the gun to pick. No mouse: the preview
# is played on the keys and the pads.
# A pad (Level3DPad) as the keys: the d-pad or the left stick, A or Start.
# Up or down held, a key or the pad, goes on down the entries.
# Each with the menus' clicks: menu_move onto another entry, menu_pick as one
# is picked (Level3DAudio).
class_name Level3DTitle
extends CanvasLayer

enum Entry { ONE_PLAYER, TWO_PLAYERS, SETTINGS, QUIT }
var _repeat := Level3DPad.Repeat.new()   # up or down held on a pad

# In the 2048x1152 layout: the scene SCENE_WIDTH wide at the middle of the
# screen (1.2 times the 2D game's title art, 25 tiles of 32 px: at its size
# the screen was half empty over and under it all), the name's
# feet NAME_GAP over its top, and the menu's first entry MENU_GAP under its
# bottom, centred on it: the entries a menu's size (Level3DFont.MENU) at the
# settings' interface scale (scale_factor), ROW_GAP between one and the
# next. The frame's last ~70 px are the ground in the dark, black on the
# black around it: the menu goes up into them, ~50 px under the last of the
# scene to be seen. A menu too tall at the larger scales to end EDGE over
# the frame's foot lifts the scene, and the name with it, as far as it needs.
const SCENE_CENTRE := Vector2(1024, 576)
const SCENE_WIDTH := 960.0
const NAME_GAP := 23.0
const MENU_GAP := -19.0
const ROW_GAP := 40.0
const EDGE := 64.0
const FRAME_HEIGHT := 1152.0
# The ▶ (Level3DSelection) is in place of the 2D game's jeep icon, which
# was the one sprite left on a screen drawn otherwise in the splash's dark and
# the sun's colours; it glides to the entry the keys pick.
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
# (game_ready): until then the title stays, black if it has faded. The
# title's song fades out from when the fade is known -- or, over the Chinook,
# reckoned, from when the jeeps are in and its ramp goes up
# (music_fade_after) -- down to nothing as the title goes black, so that the
# run's own song comes in on silence rather than cutting it off.
const LAUNCH_FADE := 0.5
# And the menu goes as they set off: the entries and the bar fade out over
# MENU_HIDE, MENU_HIDE_AFTER after the pick, once the bar's flash
# (Level3DSelection.FIRE) has been seen, leaving the scene to play alone.
const MENU_HIDE_AFTER := 0.15
const MENU_HIDE := 0.4
# And the splash comes to the middle of the screen as the menu goes, over
# MENU_FOCUS seconds, growing (Level3DSplash3D.focus): left where the title
# art was, it hung over an empty half screen.
const MENU_FOCUS := 1.4
const SCREEN_MIDDLE := Vector2(1024, 576)
# The game's name over the sun (Level3DLogo), coming up over LOGO_IN seconds
# LOGO_AFTER after the title opens -- once Level3DSplashLanding's Chinook
# has come in over the camera, so that the two do not arrive at once -- and
# going with the menu.
const LOGO_AFTER := 1.6
const LOGO_IN := 1.2
# The briefing, the intro (Level3DBriefing), is played on the splash before
# the title opens -- at the start, and again after ATTRACT_AFTER seconds on
# the title with no key touched -- the whole screen big, and ends on the
# splash's own shot: the frame comes back to its place over SETTLE seconds
# (Level3DSplash3D.settle, focus the other way) and the title opens over it,
# the name, the menu and the Chinook coming in as they always do. Held on
# its first frame till the stage under it is built (game_ready), whose
# frames are slow. Any key, button or click but the pause's (PAUSE_KEYS)
# and the seek's (SEEK_STEP) skips it: to black over SKIP_FADE and the title out of it over FROM_SKIP.
const SETTLE := 1.4
const SKIP_FADE := 0.3
const FROM_SKIP := 0.6
const ATTRACT_AFTER := 60.0
# Paused and on again, rather than skipped, by these keys or the pad's
# Back; PAUSED under it meanwhile, PAUSED_FROM_FOOT over the frame's foot.
const PAUSE_KEYS := [KEY_P, KEY_SPACE, KEY_PAUSE]
const PAUSE_BUTTON := JOY_BUTTON_BACK
const PAUSED_FROM_FOOT := 96.0
# Left and right (the arrows, the keys bound to them, the pad's d-pad) take
# it SEEK_STEP seconds back or on, paused or not, held for as long as they
# are held; on to the title's shot, it hands over as at its end.
const SEEK_STEP := 5.0

var settings: Level3DSettings
# Level3DSettings.hud_scale, the preview's to set; laid out again with it.
var scale_factor := 1.0:
	set(value):
		if value == scale_factor:
			return
		scale_factor = value
		if is_node_ready():
			_layout()
# `start.call(players)`: a game for one player or two, at settings.hard.
var start: Callable
# `open_settings.call()`: the Escape menu's settings over the title, coming
# back here when they are left (Level3DMenu.open_settings); `settings_open`
# says whether they are, and have the keys.
var open_settings: Callable
var settings_open: Callable

var _selected := 0
var _splash: Control         # Level3DSplashLanding, Level3DSplash3D or Level3DSplash
var _veil: ColorRect         # the fade to black over the launch
var _from_black: Tween       # open_from_black's
var _launching := false
var _launch: Tween           # the hold and the fade
var _waiting := 0            # players of a game whose fade the splash cannot time yet
var _music_fading := false   # the song's fade begun on the splash's reckoning
var _tell_later := false     # the splash's jeeps to be lit once the stage is built
var _menu_hide: Tween        # the entries and the bar fading out (_hide_menu)
var _game_ready := false     # the stage under the title is built (game_ready)
var _selection: Level3DSelection
var _text: Control           # the entries, in the font's filter
var _logo: Level3DLogo
var _logo_in: Tween          # the name coming up (LOGO_AFTER)
var _briefing: Level3DBriefing   # playing (open_briefing), or null
var _settling: Tween         # the splash coming back to its place after it
var _skip: Tween             # to black over a skipped one
var _idle := 0.0             # seconds on the title with no key touched (ATTRACT_AFTER)
var _paused_note: Control    # PAUSED, over a paused briefing


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	# In place of the title art: as wide as it, in the scene's own proportions
	# rather than its, centred on where it was. The scene with the Chinook
	# (level3d_splash_landing.gd); --splash-3d the jeeps' scene alone, the
	# prototype it grew from (level3d_splash3d.gd), and --splash-picture the
	# sunset as a still (level3d_splash.gd), the first of them.
	# --splash-landing, which picked the Chinook before it was the default,
	# is still taken and changes nothing.
	var splash: Control
	if OS.get_cmdline_user_args().has("--splash-picture"):
		splash = Level3DSplash.new()
	elif OS.get_cmdline_user_args().has("--splash-3d"):
		splash = Level3DSplash3D.new()
	else:
		splash = Level3DSplashLanding.new()
	add_child(splash)
	_splash = splash
	_logo = Level3DLogo.new()
	add_child(_logo)
	# Under the words.
	_selection = Level3DSelection.new()
	add_child(_selection)
	_text = Control.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.draw.connect(_draw_text)
	add_child(_text)
	_paused_note = Control.new()
	_paused_note.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paused_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paused_note.visible = false
	_paused_note.draw.connect(_draw_paused)
	add_child(_paused_note)
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_layout()


# The scene in the middle, lifted if the menu under it would run too low, the
# name over it; and the menu and its ▶ where that leaves them.
func _layout() -> void:
	_splash.place(SCENE_CENTRE, SCENE_WIDTH)
	var foot := _splash.position.y + _splash.size.y + MENU_GAP + _menu_height()
	var over := foot - (FRAME_HEIGHT - EDGE)
	if over > 0.0:
		_splash.place(SCENE_CENTRE - Vector2(0.0, roundf(over)), SCENE_WIDTH)
	_logo.centre_x = SCENE_CENTRE.x
	_logo.feet = _splash.position.y - NAME_GAP
	_logo.queue_redraw()
	_selection.aim(_slot, false)
	_text.queue_redraw()


func is_open() -> bool:
	return visible


func open() -> void:
	_idle = 0.0
	if _from_black != null:
		_from_black.kill()
		_from_black = null
	visible = true
	_launching = false
	_waiting = 0
	_music_fading = false
	if _launch != null:
		_launch.kill()
		_launch = null
	_veil.color.a = 0.0
	if _menu_hide != null:
		_menu_hide.kill()
		_menu_hide = null
	_text.modulate.a = 1.0
	_selection.modulate.a = 1.0
	if _logo_in != null:
		_logo_in.kill()
	_logo.modulate.a = 0.0
	_logo_in = create_tween()
	_logo_in.tween_interval(LOGO_AFTER)
	_logo_in.tween_property(_logo, "modulate:a", 1.0, LOGO_IN)
	if _splash != null and _splash.has_method("reset_launch"):
		_splash.reset_launch()
	_selection.park()
	_selection.aim(_slot, false)
	_redraw()
	# Opened first, while the stage is still being built under it in frames
	# up to a tenth of a second long, the jeep the menu picks is started once
	# it is built (game_ready): started in them, its nose's kick stuttered.
	# A move of the menu's lights it at once all the same.
	if _game_ready:
		_tell_splash()
	else:
		_tell_later = true


# The splash's jeeps follow the menu (Level3DSplash3D.show_menu): one jeep's
# lamps on for "1 player", both for "2 players", and the difficulty. A splash
# without show_menu, the picture, ignores it.
func _tell_splash() -> void:
	_tell_later = false
	if _splash != null and _splash.has_method("show_menu"):
		var lit := 1 if _selected == Entry.ONE_PLAYER else (2 if _selected == Entry.TWO_PLAYERS else 0)
		_splash.show_menu(lit, settings.hard)


func close() -> void:
	_stop_briefing()
	visible = false


# Whether the splash can play the briefing: the 3D one, and the files there.
func can_brief() -> bool:
	return _splash is Level3DSplash3D and Level3DBriefing.available()


# The title opened on the briefing (SETTLE, ATTRACT_AFTER), or at once
# where there is none.
func open_briefing() -> void:
	if not can_brief():
		open()
		return
	_stop_briefing()
	visible = true
	_launching = false
	_veil.color.a = 0.0
	for tween in [_from_black, _menu_hide, _logo_in]:
		if tween != null:
			(tween as Tween).kill()
	_text.modulate.a = 0.0
	_selection.modulate.a = 0.0
	_logo.modulate.a = 0.0
	var splash := _splash as Level3DSplash3D
	splash.reset_launch()
	splash.show_menu(0, settings.hard)
	_briefing = splash.play_briefing()
	_briefing.playing = _game_ready
	_briefing.arrived.connect(_briefing_arrived)


# On the splash's own shot: the frame back to its place, and the title.
func _briefing_arrived() -> void:
	_pause_briefing(false)
	(_splash as Level3DSplash3D).end_briefing(SETTLE)
	_briefing = null
	_settling = create_tween()
	_settling.tween_interval(SETTLE)
	_settling.tween_callback(func():
		_settling = null
		_open_after_briefing(false))


func _open_after_briefing(from_black: bool) -> void:
	if from_black:
		open_from_black(FROM_SKIP)
	else:
		open()
	_text.modulate.a = 0.0
	_selection.modulate.a = 0.0
	var menu_in := create_tween().set_parallel()
	menu_in.tween_property(_text, "modulate:a", 1.0, LOGO_IN)
	menu_in.tween_property(_selection, "modulate:a", 1.0, LOGO_IN)


# Skipped: to black, and the title out of it.
func _skip_briefing() -> void:
	if _skip != null:
		return
	_skip = create_tween()
	_skip.tween_property(_veil, "color:a", 1.0, SKIP_FADE)
	_skip.tween_callback(func():
		_skip = null
		_stop_briefing()
		_open_after_briefing(true))


# -1 back, 1 on, 0 neither: a press or its repeat.
func _seek_of(event: InputEvent) -> int:
	var key := event as InputEventKey
	if key != null and key.pressed:
		if key.keycode in [KEY_LEFT, settings.key("left")]:
			return -1
		if key.keycode in [KEY_RIGHT, settings.key("right")]:
			return 1
	var button := event as InputEventJoypadButton
	if button != null and button.pressed:
		if button.button_index == JOY_BUTTON_DPAD_LEFT:
			return -1
		if button.button_index == JOY_BUTTON_DPAD_RIGHT:
			return 1
	return 0


func _is_pause(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null:
		return key.keycode in PAUSE_KEYS
	var button := event as InputEventJoypadButton
	return button != null and button.button_index == PAUSE_BUTTON


# The briefing held or on again (PAUSE_KEYS); once it has come to the
# title's shot there is nothing to hold.
func _pause_briefing(on: bool) -> void:
	if _briefing != null:
		_briefing.paused = on
	_paused_note.visible = on and _briefing != null
	_paused_note.queue_redraw()


func _draw_paused() -> void:
	var g := Level3DFont.size(Level3DFont.SMALL, scale_factor)
	var text := "paused"
	Level3DFont.draw(_paused_note, text, roundf(SCREEN_MIDDLE.x - Level3DFont.width(text, g) * 0.5),
			FRAME_HEIGHT - PAUSED_FROM_FOOT, g, Level3DFont.WHITE, PICKED_TINT)


func _stop_briefing() -> void:
	_pause_briefing(false)
	for tween in [_settling, _skip]:
		if tween != null:
			(tween as Tween).kill()
	_settling = null
	_skip = null
	if _briefing != null:
		(_splash as Level3DSplash3D).end_briefing(0.0)
		_briefing = null


func is_briefing() -> bool:
	return _briefing != null or _settling != null


# Whether its bar is up: while the title is and the settings are not over it.
func _selection_up() -> bool:
	return visible and not (settings_open.is_valid() and settings_open.call())


# The stage under the title is built, and a game can start (Level3DPreview's
# _ready builds it under the title); the splash is told, for a Chinook that
# waits for it to lift off.
func game_ready() -> void:
	_game_ready = true
	if _briefing != null:
		_briefing.playing = true
	if _splash != null and _splash.has_method("game_ready"):
		_splash.game_ready()
	if _tell_later and visible and not _launching:
		_tell_splash()


func _entries() -> Array[String]:
	return ["1 player", "2 players", "settings", "quit"]


# The menu's top left: under the scene, MENU_GAP clear of it, the widest
# entry centred on it.
func _menu_at() -> Vector2:
	var widest := 0.0
	for entry in _entries():
		widest = maxf(widest, Level3DFont.width(entry, _glyph()))
	return Vector2(roundf(SCENE_CENTRE.x - widest * 0.5), _splash.position.y + _splash.size.y + MENU_GAP)


# The entries' size, and from one entry's top to the next's.
func _glyph() -> float:
	return Level3DFont.size(Level3DFont.MENU, scale_factor)


func _row() -> float:
	return _glyph() + ROW_GAP


func _menu_height() -> float:
	return (_entries().size() - 1) * _row() + _glyph()


func _process(delta: float) -> void:
	if _waiting > 0 and _launch == null:
		if not _music_fading and _splash.has_method("music_fade_after"):
			var soon: float = _splash.call("music_fade_after")
			if not is_inf(soon):
				_music_fading = true
				Level3DAudio.fade_music(soon + LAUNCH_FADE)
		var after: float = _splash.call("fade_after")
		if not is_inf(after):
			var count := _waiting
			_waiting = 0
			_fade_out(count, after)
	if not visible:
		return
	# Left on the title long enough, it plays the briefing again.
	if not _launching and not is_briefing() and not (settings_open.is_valid() and settings_open.call()):
		_idle += delta
		if _idle >= ATTRACT_AFTER:
			open_briefing()
			return
	if not _launching and not is_briefing() and not (settings_open.is_valid() and settings_open.call()):
		var again := _repeat.tick(Level3DPad.held_dir(Level3DPad.connected()), delta)
		if again.y != 0:
			_select(_selected + again.y)
	_selection.visible = _selection_up()
	# Until the HUD's crosshair, which owns the mouse mode, is made under the
	# title (Level3DPreview._ready), nobody else hides the pointer.
	if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


# Before the entry picked, where Menu's icon stood: the entry picked's words.
func _slot() -> Rect2:
	var entry: String = _entries()[_selected]
	var g := _glyph()
	return Rect2(_menu_at() + Vector2(0.0, _selected * _row()), Vector2(Level3DFont.width(entry, g), g))


# Onto another entry, with its click unless `quiet` -- a click on it, whose
# pick clicks.
func _select(index: int, quiet := false) -> void:
	index = clampi(index, 0, Entry.size() - 1)
	if index == _selected:
		return
	_selected = index
	if not quiet:
		Level3DAudio.play("menu_move")
	_selection.aim(_slot)
	_text.queue_redraw()
	_tell_splash()


func _pick() -> void:
	_selection.fire()
	Level3DAudio.play("menu_pick")
	match _selected:
		Entry.ONE_PLAYER, Entry.TWO_PLAYERS:
			var count := _selected + 1
			_hide_menu()
			if _splash != null and _splash.has_method("launch"):
				_launching = true
				_fade_out(count, _splash.call("launch", count))
			else:
				_launching = true
				_begin(count)
		Entry.SETTINGS:
			open_settings.call()
		Entry.QUIT:
			get_tree().quit()


# The entries, the bar and the name out of the way of the launch
# (MENU_HIDE), and the splash to the middle (MENU_FOCUS).
func _hide_menu() -> void:
	if _menu_hide != null:
		_menu_hide.kill()
	_menu_hide = create_tween()
	_menu_hide.tween_interval(MENU_HIDE_AFTER)
	_menu_hide.tween_property(_text, "modulate:a", 0.0, MENU_HIDE)
	_menu_hide.parallel().tween_property(_selection, "modulate:a", 0.0, MENU_HIDE)
	if _logo_in != null:
		_logo_in.kill()
	_menu_hide.parallel().tween_property(_logo, "modulate:a", 0.0, MENU_HIDE)
	if _splash != null and _splash.has_method("focus"):
		_splash.focus(SCREEN_MIDDLE, MENU_FOCUS)


# Opened under black, which lifts off it over `seconds`, eased: from the game
# over's END (Level3DGameOverScreen), which leaves to black slowly and would
# otherwise cut to the title at once.
func open_from_black(seconds: float) -> void:
	open()
	_veil.color.a = 1.0
	_from_black = create_tween()
	_from_black.tween_property(_veil, "color:a", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_from_black.tween_callback(func(): _from_black = null)


# The title fading out over the launch after `hold` seconds, and the run; an
# infinite hold waits for the splash to say (_process).
func _fade_out(count: int, hold: float) -> void:
	if _from_black != null:
		_from_black.kill()
		_from_black = null
	if _launch != null:
		_launch.kill()
		_launch = null
	if is_inf(hold):
		_waiting = count
		return
	var fade := LAUNCH_FADE * (1.0 - _veil.color.a)
	Level3DAudio.fade_music(hold + fade)
	_launch = create_tween()
	_launch.tween_interval(hold)
	_launch.tween_property(_veil, "color:a", 1.0, fade)
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


func _redraw() -> void:
	_text.queue_redraw()
	_text.texture_filter = Level3DFont.filter()
	_logo.restyle()


func _input(event: InputEvent) -> void:
	# The settings over the title have the keys while they are open; while
	# the jeeps drive off, a key or a button only hurries the fade on.
	if not visible or settings_open.is_valid() and settings_open.call():
		return
	var touched: bool = event is InputEventKey and event.pressed and not event.echo 			or event is InputEventJoypadButton and event.pressed 			or event is InputEventMouseButton and event.pressed
	if touched:
		_idle = 0.0
	if is_briefing():
		var seek := _seek_of(event)
		if seek != 0:
			if _briefing != null:
				_briefing.seek(_briefing.time + seek * SEEK_STEP)
			get_viewport().set_input_as_handled()
			return
		if touched:
			if _is_pause(event):
				_pause_briefing(not _briefing.paused if _briefing != null else false)
			else:
				_skip_briefing()
			get_viewport().set_input_as_handled()
		return
	if _launching:
		var pressed: bool = event is InputEventKey and event.pressed and not event.echo \
				or event is InputEventJoypadButton and event.pressed
		if pressed and (_launch != null or _waiting > 0) and _veil.color.a == 0.0:
			_waiting = 0
			_fade_out(_selected + 1, 0.0)
			get_viewport().set_input_as_handled()
		return
	var move := Level3DPad.nav(event)
	if move != Vector2i.ZERO or Level3DPad.is_accept(event):
		if move.y != 0:
			_select(_selected + move.y)
		elif move.x == 0:
			_pick()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and (not key.echo
			or key.keycode in [KEY_UP, KEY_DOWN, settings.key("up"), settings.key("down")]):
		var code := key.keycode
		if code in [KEY_UP, settings.key("up")]:
			_select(_selected - 1)
		elif code in [KEY_DOWN, settings.key("down")]:
			_select(_selected + 1)
		elif code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, settings.key("gun")]:
			_pick()
		else:
			return
		get_viewport().set_input_as_handled()


func _draw_text() -> void:
	var entries := _entries()
	var at := _menu_at()
	var g := _glyph()
	for i in entries.size():
		Level3DFont.draw(_text, entries[i], at.x, at.y + i * _row(), g,
				Level3DFont.WHITE, PICKED_TINT if i == _selected else OTHER_TINT)
