# The 3D preview's game over screen, the 2D game's ContinueMode in the
# cemetery: once every player is out and the GAME OVER banner has stood
# (level3d_preview.gd, _game_over), the stage goes to black and the cemetery
# (Level3DGameOver) comes up out of it, the prisoners the players rescued
# saluting their graves, with its song. Over it, and nothing else:
#
#     KILLED IN ACTION            at the top, over the sky, once the guard
#                                 has saluted (TITLE_AFTER), slowly
#     CONTINUE    END             small at the bottom, by itself a little
#                                 after (MENU_AFTER)
#
# The score, the prisoners each brought in and PRESS ANY KEY went, and the
# summary's plate (Level3DSummary.draw_plate) they stood on, which covered
# half the frame and broke the burial: the guard says who brought in how
# many. KIA rather than MIA -- the players are in those graves.
#
# The choice is ContinueMode's "continue" with yes and no: CONTINUE, the
# stage again from the Chinook with fresh lives and the score from nothing,
# as the game's continue_player does, both players in again; END, the title
# screen, as its "no" goes to IntroMode. Picked as the title's entries are:
# left and right (or up and down, and the keys bound to the BTR's), Enter,
# Space or the gun, the mouse's reticle (Level3DReticle) aimed at an entry
# and clicked, with the menus' clicks. A key, a mouse button or a pad's
# before the menu is up brings it up at once. At the pick the guard lowers
# its hands (Level3DGameOver.lower_salute); then to black, the song fading
# with it, and `continue_game` or `end_game` under the black; on CONTINUE the
# black lifts off the stage. END goes slowly (END_*), a farewell: the hands
# down first, a long eased fade, a beat of black, the title out of it.
#
# Its own layer, over the HUD and under the title (which END opens over it)
# and the Escape menu, processing while the tree is paused -- the preview
# pauses the stage under it, and so is not there to open the Escape menu.
# The cemetery is made the first time it is wanted, under the black: its glb
# and the guard's are a pause to load that the preview's start need not pay.
# It is on a layer of its own under this one (`scene_layer`), so that the
# preview's pixels (8-bit's look) take it as they take the stage, while the
# words over it stay sharp as the HUD's do; and the HUD (`hud`), which would
# be between the two, is hidden while it stands.
class_name Level3DGameOverScreen
extends CanvasLayer

const TITLE := "KILLED IN ACTION"
const ENTRIES: Array[String] = ["CONTINUE", "END"]
const TITLE_GLYPH := 48.0
const GLYPH := 24.0             # the entries'
const TOP := 72.0               # the title's top from the frame's
const BOTTOM := 64.0            # the entries' foot from the frame's
const ENTRY_GAP := 120.0        # between CONTINUE and END
const RETICLE_X := -44.0        # where the reticle stands before an entry
# The title's tints (Level3DTitle): the entry picked in the sun's yellow, the
# other a dim copper.
const PICKED_TINT := Level3DTitle.PICKED_TINT
const OTHER_TINT := Level3DTitle.OTHER_TINT
const FADE_OUT := 0.6           # the stage to black
const FADE_IN := 0.8            # the cemetery out of it
# From the cemetery's first frame: the title once the guard has saluted, in
# over TITLE_IN; the entries a little after, in over MENU_IN.
const TITLE_AFTER := 2.4
const TITLE_IN := 1.2
const MENU_AFTER := 4.4
const MENU_IN := 0.6
const LEAVE := 0.6              # to black once CONTINUE is picked
const LIFT := 0.6               # the black off the stage, on CONTINUE
# END is a farewell, and slower: the guard's hands down first (END_HOLD), the
# cemetery to black over END_LEAVE, eased, its song and rain with it, a beat
# of black (END_BLACK), and the title out of the black over END_LIFT
# (`end_game`, which the preview's title does: Level3DTitle.open_from_black).
const END_HOLD := 0.7
const END_LEAVE := 2.0
const END_BLACK := 0.4
const END_LIFT := 1.6

enum State { CLOSED, DARKENING, TELLING, MENU, LEAVING }

# `continue_game.call()` and `end_game.call()`, under the black.
var continue_game: Callable
var end_game: Callable
var scale_factor := 1.0
# What the cemetery shows, set by `open`: each player's rescued, the
# prisoners there were.
var rescued: Array[int] = []
var total := 0
# The cemetery's layer, under this one's; -1 for the one just under it.
var scene_layer := -1
# The layer hidden while the cemetery stands, or null.
var hud: CanvasLayer

var _state := State.CLOSED
var _scene: Level3DGameOver
var _scene_layer: CanvasLayer
var _text: Control
var _reticle: Level3DReticle
var _veil: ColorRect
var _fade: Tween
var _time := 0.0                # since the cemetery came up
var _menu_from := 0.0           # _time the entries came in from
var _selected := 0
var _entry_rects: Array[Rect2] = []   # this frame's, for the mouse


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_text = Control.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.draw.connect(_draw_text)
	add_child(_text)
	_reticle = Level3DReticle.new()
	_reticle.carries_mouse = true
	_reticle.shown = false
	add_child(_reticle)
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


func is_open() -> bool:
	return _state != State.CLOSED


# The system's pointer hidden the whole time it is up -- the reticle in its
# place while there is a choice to aim at -- for Level3DCrosshair, which owns
# the mouse mode.
func pointer_hidden() -> bool:
	return is_open()


# The run's end: `p_rescued` each player's rescued, one entry each, `p_total`
# the prisoners there were. From the stage, to black over FADE_OUT;
# `at_once` straight to the cemetery, for --game-over and
# tools/game_over_shot.gd.
func open(p_rescued: Array[int], p_total: int, at_once := false) -> void:
	rescued = p_rescued.duplicate()
	total = p_total
	visible = true
	_state = State.DARKENING
	_kill_fade()
	if at_once:
		_veil.color.a = 1.0
		_show_cemetery()
		return
	Level3DAudio.fade_music(FADE_OUT)
	_fade = create_tween()
	_fade.tween_property(_veil, "color:a", 1.0, FADE_OUT * (1.0 - _veil.color.a))
	_fade.tween_callback(_show_cemetery)


# Off at once, the cemetery cleared: under the title, or for a run started
# again from under it.
func close() -> void:
	_kill_fade()
	_state = State.CLOSED
	visible = false
	_veil.color.a = 0.0
	_reticle.shown = false
	if _scene != null:
		_scene.clear()
	if hud != null:
		hud.visible = true


func _show_cemetery() -> void:
	_fade = null
	if _scene == null:
		_scene_layer = CanvasLayer.new()
		_scene_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_scene_layer)
		_scene = Level3DGameOver.new()
		_scene_layer.add_child(_scene)
	_scene_layer.layer = scene_layer if scene_layer >= 0 else layer - 1
	if hud != null:
		hud.visible = false
	var shown: Array = []
	for n in rescued:
		shown.append(n)
	_scene.show_game_over(shown, total)
	_time = 0.0
	_selected = 0
	_state = State.TELLING
	Level3DAudio.play_music("continue")
	_fade = create_tween()
	_fade.tween_property(_veil, "color:a", 0.0, FADE_IN)
	_fade.tween_callback(func(): _fade = null)


func _kill_fade() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null


func _process(delta: float) -> void:
	if _state == State.CLOSED:
		return
	if _state in [State.TELLING, State.MENU]:
		_time += delta
	if _state == State.TELLING and _time >= MENU_AFTER and _veil.color.a == 0.0:
		_to_menu()
	_reticle.shown = _state == State.MENU and _veil.color.a == 0.0
	_text.texture_filter = Level3DFont.filter()
	_text.queue_redraw()


# The choice picked: the guard's hands down, the song and the cemetery to
# black, then the caller's -- slowly for END (END_*).
func _pick() -> void:
	_reticle.fire()
	Level3DAudio.play("menu_pick")
	_state = State.LEAVING
	var go_on := _selected == 0
	var hold := Level3DReticle.FIRE if go_on else END_HOLD
	var leave := LEAVE if go_on else END_LEAVE
	Level3DAudio.fade_music(hold + leave)
	if _scene != null:
		_scene.lower_salute()
		_scene.fade_rain(hold + leave)
	_kill_fade()
	_fade = create_tween()
	_fade.tween_interval(hold)
	if go_on:
		_fade.tween_property(_veil, "color:a", 1.0, leave)
	else:
		_fade.tween_property(_veil, "color:a", 1.0, leave).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_fade.tween_interval(END_BLACK)
	_fade.tween_callback(func():
		_fade = null
		if _scene != null:
			_scene.clear()
		_text.queue_redraw()
		if go_on:
			if continue_game.is_valid():
				continue_game.call()
			_lift()
		else:
			if end_game.is_valid():
				end_game.call()
			close())


# The black off the stage the run starts again on, and the screen gone.
func _lift() -> void:
	_state = State.LEAVING
	_reticle.shown = false
	_fade = create_tween()
	_fade.tween_property(_veil, "color:a", 0.0, LIFT)
	_fade.tween_callback(close)


func _select(index: int, quiet := false) -> void:
	index = clampi(index, 0, ENTRIES.size() - 1)
	if index == _selected:
		return
	_selected = index
	if not quiet:
		Level3DAudio.play("menu_move")
	_reticle.aim(_slot)


# Before the entry picked, half a glyph down: where the title has its reticle.
func _slot() -> Vector2:
	if _entry_rects.size() <= _selected:
		return Vector2.ZERO
	var at := _entry_rects[_selected]
	return Vector2(at.position.x + RETICLE_X * scale_factor, at.get_center().y)


func _input(event: InputEvent) -> void:
	if _state == State.CLOSED:
		return
	# Nothing gets past it to the stage paused under it, or the title's keys.
	if _state != State.TELLING and _state != State.MENU:
		if _is_press(event):
			get_viewport().set_input_as_handled()
		return
	if _state == State.TELLING:
		if not _is_press(event):
			return
		get_viewport().set_input_as_handled()
		# The title and the entries at once, not a pick yet.
		if _veil.color.a == 0.0:
			_time = maxf(_time, TITLE_AFTER + TITLE_IN)
			_to_menu()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var code := key.keycode
		var settings := _settings()
		if code != KEY_ESCAPE:
			_reticle.keys()
		if code in [KEY_LEFT, KEY_UP] or settings != null and code in [settings.key("left"), settings.key("up")]:
			_select(_selected - 1)
		elif code in [KEY_RIGHT, KEY_DOWN] or settings != null and code in [settings.key("right"), settings.key("down")]:
			_select(_selected + 1)
		elif code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or settings != null and code == settings.key("gun"):
			_pick()
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var at := _entry_at()
		if _reticle.mouse_has_it() and at >= 0:
			_select(at)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		get_viewport().set_input_as_handled()
		if click.button_index == MOUSE_BUTTON_LEFT:
			var at := _entry_at()
			if at >= 0:
				_select(at, true)
				_pick()
		return
	var pad := event as InputEventJoypadButton
	if pad != null and pad.pressed:
		get_viewport().set_input_as_handled()
		match pad.button_index:
			JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP:
				_select(_selected - 1)
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN:
				_select(_selected + 1)
			JOY_BUTTON_A, JOY_BUTTON_START:
				_pick()


func _to_menu() -> void:
	_state = State.MENU
	_menu_from = _time
	_selected = 0
	_text.queue_redraw()
	# Placed once the entries are drawn, the next frame.
	await get_tree().process_frame
	_reticle.park()
	_reticle.aim(_slot, false)


# A key, a button of the mouse but its wheel, or a pad's, pressed.
static func _is_press(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo \
			or event is InputEventMouseButton and event.pressed and event.button_index not in [
				MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT] \
			or event is InputEventJoypadButton and event.pressed


# The preview's settings, for the keys bound to the BTR's; none in a tool.
func _settings() -> Level3DSettings:
	var preview := get_parent()
	if preview != null and "settings" in preview:
		return preview.settings as Level3DSettings
	return null


func _entry_at() -> int:
	var p := _text.get_local_mouse_position()
	for i in _entry_rects.size():
		# From where the reticle stands before it to its end.
		var reach := -RETICLE_X * scale_factor + 24.0
		if _entry_rects[i].grow_individual(reach, 12.0, 12.0, 12.0).has_point(p):
			return i
	return -1


func _draw_text() -> void:
	if _state == State.CLOSED or _scene == null or not _scene.shown:
		return
	var s := scale_factor
	var size := _text.size
	var shown := clampf((_time - TITLE_AFTER) / TITLE_IN, 0.0, 1.0)
	if shown > 0.0:
		var tg := _whole(TITLE_GLYPH * s)
		Level3DFont.draw(_text, TITLE, roundf(size.x * 0.5 - Level3DFont.width(TITLE, tg) * 0.5),
				roundf(TOP * s), tg, Level3DFont.WHITE, Color(1.0, 1.0, 1.0, shown))
	_entry_rects.clear()
	if _state != State.MENU and _state != State.LEAVING:
		return
	# CONTINUE and END side by side, small, at the foot of the frame.
	var menu := clampf((_time - _menu_from) / MENU_IN, 0.0, 1.0)
	var g := _whole(GLYPH * s)
	var entry_gap := roundf(ENTRY_GAP * s)
	var row := Level3DFont.width(ENTRIES[0], g) + entry_gap + Level3DFont.width(ENTRIES[1], g)
	var x := roundf(size.x * 0.5 - row * 0.5)
	var y := roundf(size.y - BOTTOM * s - g)
	for i in ENTRIES.size():
		var w := Level3DFont.width(ENTRIES[i], g)
		_entry_rects.append(Rect2(x, y, w, g))
		var tint: Color = PICKED_TINT if i == _selected else OTHER_TINT
		tint.a *= menu
		Level3DFont.draw(_text, ENTRIES[i], x, y, g, Level3DFont.WHITE, tint)
		x += w + entry_gap


static func _whole(g: float) -> float:
	return maxf(roundf(g / 8.0), 1.0) * 8.0
