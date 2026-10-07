# The 3D preview's menus' pointer, in place of the system's: the title screen's
# (Level3DTitle) and the Escape menu's (Level3DMenu). The game's own reticle,
# what the mouse aims with in a run (Main.draw_crosshair, Level3DCrosshair),
# at SCALE, in the sun's colour over its black pass -- the title is drawn in
# the splash's dark and the sun's colours -- breathing, its gap PULSE px in
# and out every BREATH seconds.
#
# The keys and the pads glide it, over GLIDE seconds, speeding up and
# slowing as the 2D game's Menu icon does, to whatever its owner aims it at
# (aim): before the title's entry, beside the Escape menu's focused control.
# A pick closes it in and flashes it (fire). The preview is played without
# the mouse, which neither moves it nor picks.
#
# A list dropped from a menu is a window of its own, drawn over every layer
# and so over the reticle: in it the menu puts a second one, `mirror` of the
# first, which stands where the first does, breathes and flashes with it, and
# is drawn over the list's items.
#
# The system pointer is hidden the whole time (Level3DCrosshair).
class_name Level3DReticle
extends Control

const SCALE := 1.25
const COLOUR := Color(0.965, 0.627, 0.118)
const FLASH := Color(1.0, 0.93, 0.62)
const BREATH := 1.4
const PULSE := 2.0
const GLIDE := 0.12
const FIRE := 0.3
const CLOSE := 6.0             # px the gap closes by at a pick

var shown := true
var mirror: Level3DReticle     # the reticle this one copies, from a list's window

var _at := Vector2.ZERO
var _from := Vector2.ZERO      # where its glide started
var _moving := 1.0             # 0 to 1 of its glide, 1 when it stands
var _target: Callable          # -> Vector2, where the keys have it
var _time := 0.0
var _fired := 1.0              # 0 to 1 of a pick's closing in, 1 when over


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


# To `target.call()`: gliding there, or put there at once.
func aim(target: Callable, glide := true) -> void:
	_target = target
	if glide:
		_from = _at
		_moving = 0.0
	else:
		_moving = 1.0
		_at = target.call()


# The menu opened: no pick closing it in.
func park() -> void:
	_fired = 1.0


func fire() -> void:
	_fired = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if is_instance_valid(mirror):
		_copy()
		return
	_time += delta
	if _target.is_valid():
		var goal: Vector2 = _target.call()
		if _moving < 1.0:
			_moving = minf(_moving + delta / GLIDE, 1.0)
			var t := _moving
			var eased := 2.0 * t * t if t < 0.5 else 1.0 - 2.0 * (1.0 - t) * (1.0 - t)
			_at = _from.lerp(goal, eased)
		else:
			_at = goal
	_fired = minf(_fired + delta / FIRE, 1.0)
	queue_redraw()


# Where `mirror` stands, from its canvas into this window's: the list is
# embedded in the viewport the menu is drawn in, at its window's position.
func _copy() -> void:
	var on_screen := mirror.get_global_transform_with_canvas() * mirror._at
	_at = get_global_transform_with_canvas().affine_inverse() * (on_screen - Vector2(get_window().position))
	_time = mirror._time
	_fired = mirror._fired
	shown = mirror.shown
	queue_redraw()


# As Level3DCrosshair draws the game's, bigger and in the sun's colour, its
# gap breathing and closing in at a pick; whole pixels, which a reticle
# between two would blur.
func _draw() -> void:
	if not shown:
		return
	var at := _at.round()
	var unit := roundf(Main.CROSSHAIR_UNIT * SCALE)
	var arm := roundf(Main.CROSSHAIR_ARM * SCALE)
	var fire := 1.0 - _fired
	var gap := roundf(Main.CROSSHAIR_GAP * SCALE + sin(_time * TAU / BREATH) * PULSE - fire * CLOSE)
	var half := unit * 0.5
	var bars: Array[Rect2] = [
		Rect2(at.x + gap, at.y - half, arm, unit),          # east
		Rect2(at.x - gap - arm, at.y - half, arm, unit),    # west
		Rect2(at.x - half, at.y + gap, unit, arm),          # south
		Rect2(at.x - half, at.y - gap - arm, unit, arm),    # north
	]
	for bar in bars:
		draw_rect(bar.grow(half), Main.CROSSHAIR_OUTLINE, true)
	var colour := COLOUR.lerp(FLASH, fire)
	for bar in bars:
		draw_rect(bar, colour, true)
