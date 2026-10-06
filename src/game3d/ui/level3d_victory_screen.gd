# The 3D preview's mission's end screen -- made, not yet opened by the
# preview, which still shows the summary over the stage; tools/victory_shot.gd
# shows it. Once the fourth boss tank has gone and the stage has stood a
# moment over its blast, the stage is to go to black and the mission's end
# (Level3DVictory) comes up out of it -- the players' jeeps from behind,
# the boss's wrecks burning up the arena -- and over it, from SUMMARY_AFTER,
# the mission's summary (Level3DSummary): MISSION ACCOMPLISHED! typed, the
# prisoners each player brought in, the count and the time, PRESS ANY KEY.
# With no plate, at the top of the frame (SUMMARY_TOP): it was a plate across
# the stage, over the boss's wrecks, and the scene is the picture now.
#
# A key, a mouse button or a pad's before the summary is all there brings it
# all at once; once it is, it closes it, and the scene goes to black over
# LEAVE and `done` is called under the black -- the preview's shop, which
# comes up out of it. The music is the boss's: its end plays on, a victory's
# (Level3DAudio's adaptive boss song), and is faded with the scene.
#
# Its own layer, as the game over's (Level3DGameOverScreen): over the HUD,
# processing while the tree is paused -- the preview pauses the stage under
# it -- the scene on a layer of its own under this one (`scene_layer`), so
# that the preview's pixels (8-bit's look) take it as they take the stage,
# while the words over it stay sharp; the HUD (`hud`) hidden while it stands.
# The scene is made the first time it is wanted, under the black.
class_name Level3DVictoryScreen
extends CanvasLayer

const FADE_OUT := 0.8           # the stage to black
const FADE_IN := 1.0            # the scene out of it
const SUMMARY_AFTER := 1.6      # from the scene's first frame
const SUMMARY_TOP := 48.0       # the summary's top, px at 100%
const LEAVE := 0.8              # to black once the summary is closed

enum State { CLOSED, DARKENING, SHOWING, LEAVING }

# `done.call()`, under the black once it is left.
var done: Callable
var scale_factor := 1.0:
	set(value):
		scale_factor = value
		if summary != null:
			summary.scale_factor = value
# The scene's layer, under this one's; -1 for the one just under it.
var scene_layer := -1
# The layer hidden while the scene stands, or null.
var hud: CanvasLayer
# The summary, which the preview gives its icons (Level3DSummary.icons).
var summary: Level3DSummary

var _state := State.CLOSED
var _scene: Level3DVictory
var _scene_layer: CanvasLayer
var _veil: ColorRect
var _fade: Tween
var _time := 0.0
# What it shows, set by `open`.
var _rescued_by: Array[int] = []
var _total := 0
var _ticks := 0
var _paints: Array[String] = []
var _kits: Array = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	summary = Level3DSummary.new()
	summary.plate = false
	summary.top = SUMMARY_TOP
	summary.closed = _leave
	add_child(summary)
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


func is_open() -> bool:
	return _state != State.CLOSED


# The system's pointer hidden while it is up, for Level3DCrosshair.
func pointer_hidden() -> bool:
	return is_open()


# The mission's end: `rescued_by` the player of each prisoner rescued,
# `total` the prisoners there were, `ticks` the mission's time; each player's
# jeep's paint (`paints`) and kit (`kits`, Level3DRun.Kit). From the stage,
# to black over FADE_OUT; `at_once` straight to the scene, for
# tools/victory_shot.gd.
func open(rescued_by: Array[int], total: int, ticks: int, paints: Array[String], kits: Array,
		at_once := false) -> void:
	_rescued_by = rescued_by.duplicate()
	_total = total
	_ticks = ticks
	_paints = paints.duplicate()
	_kits = kits.duplicate()
	visible = true
	_state = State.DARKENING
	_kill_fade()
	if at_once:
		_veil.color.a = 1.0
		_show_scene()
		return
	_fade = create_tween()
	_fade.tween_property(_veil, "color:a", 1.0, FADE_OUT * (1.0 - _veil.color.a))
	_fade.tween_callback(_show_scene)


# Off at once, the scene cleared.
func close() -> void:
	_kill_fade()
	_state = State.CLOSED
	visible = false
	_veil.color.a = 0.0
	summary.clear()
	if _scene != null:
		_scene.clear()
	if hud != null:
		hud.visible = true


func _show_scene() -> void:
	_fade = null
	if _scene == null:
		_scene_layer = CanvasLayer.new()
		_scene_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_scene_layer)
		_scene = Level3DVictory.new()
		_scene_layer.add_child(_scene)
	_scene_layer.layer = scene_layer if scene_layer >= 0 else layer - 1
	if hud != null:
		hud.visible = false
	_scene.show_victory(_paints, _kits)
	_time = 0.0
	_state = State.SHOWING
	_fade = create_tween()
	_fade.tween_property(_veil, "color:a", 0.0, FADE_IN)
	_fade.tween_callback(func(): _fade = null)


func _kill_fade() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null


func _process(delta: float) -> void:
	if _state != State.SHOWING:
		return
	_time += delta
	if not summary.shown and _time >= SUMMARY_AFTER:
		_summarise()


func _summarise() -> void:
	summary.show_summary(_rescued_by, _total, _ticks)


# The summary closed (Level3DSummary.closed): the scene and the music to
# black, then the caller's under it, and the screen gone.
func _leave() -> void:
	if _state != State.SHOWING:
		return
	_state = State.LEAVING
	Level3DAudio.fade_music(LEAVE)
	_kill_fade()
	_fade = create_tween()
	_fade.tween_property(_veil, "color:a", 1.0, LEAVE)
	_fade.tween_callback(func():
		_fade = null
		if done.is_valid():
			done.call()
		close())


func _input(event: InputEvent) -> void:
	if _state == State.CLOSED:
		return
	# Nothing gets past it to the stage paused under it.
	if not Level3DGameOverScreen._is_press(event):
		return
	get_viewport().set_input_as_handled()
	if _state != State.SHOWING or _veil.color.a > 0.0:
		return
	if not summary.shown:
		_summarise()
	summary.dismiss()
