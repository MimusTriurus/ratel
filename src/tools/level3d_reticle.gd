# The 3D preview's menus' pointer, in place of the system's: the title screen's
# (Level3DTitle) and the Escape menu's (Level3DMenu). The game's own reticle,
# what the mouse aims with in a run (Main.draw_crosshair, Level3DCrosshair),
# at SCALE, in the sun's colour over its black pass -- the title is drawn in
# the splash's dark and the sun's colours -- breathing, its gap PULSE px in
# and out every BREATH seconds.
#
# The mouse moves it freely; the keys glide it, over GLIDE seconds, speeding
# up and slowing as the 2D game's Menu icon does, to whatever its owner aims
# it at (aim): before the title's entry, beside the Escape menu's focused
# control. Whichever moved last has it -- the mouse once it has moved
# MOUSE_TAKES px from where it was when the keys took it, since the window's
# own motion events, coming with the focus, took it to wherever the pointer
# happened to sit. A pick closes it in and flashes it (fire).
#
# With `carries_mouse` the hidden system pointer goes with the keys: put at
# once where they glide it to, so that the mouse, taking it again, starts from
# the entry rather than throwing it in one frame to wherever the pointer was
# left. Not while the window is out of focus, whose pointer is the user's.
#
# The owner hides the system pointer while it is `shown`, and says so to
# Level3DCrosshair, which owns the mouse mode.
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
const MOUSE_TAKES := 8.0

var shown := true
var by_mouse := false          # the mouse has it, rather than the keys
var carries_mouse := false     # the keys take the system pointer along

var _at := Vector2.ZERO
var _from := Vector2.ZERO      # where its glide started
var _moving := 1.0             # 0 to 1 of its glide, 1 when it stands
var _target: Callable          # -> Vector2, where the keys have it
var _time := 0.0
var _fired := 1.0              # 0 to 1 of a pick's closing in, 1 when over
var _parked := Vector2.ZERO    # the mouse when the keys took it


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


# The keys have it, `target.call()` where: gliding there, or put there at once.
# With the mouse in charge it only remembers where.
func aim(target: Callable, glide := true) -> void:
	_target = target
	if by_mouse:
		return
	if glide:
		_from = _at
		_moving = 0.0
	else:
		_moving = 1.0
		_at = target.call()


# The keys take it back from the mouse; it glides from where the mouse left it.
func keys() -> void:
	_parked = get_local_mouse_position()
	if by_mouse:
		by_mouse = false
		_from = _at
		_moving = 0.0


# The menu opened: the keys have it, wherever the pointer is.
func park() -> void:
	_parked = get_local_mouse_position()
	by_mouse = false
	_fired = 1.0


func fire() -> void:
	_fired = 0.0


# Whether the mouse has it, taking it if it has moved far enough to mean it.
func mouse_has_it() -> bool:
	if not by_mouse and get_local_mouse_position().distance_to(_parked) > MOUSE_TAKES:
		by_mouse = true
	return by_mouse


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	if mouse_has_it():
		_at = get_local_mouse_position()
	elif _target.is_valid():
		var goal: Vector2 = _target.call()
		if carries_mouse and get_window().has_focus() \
				and get_local_mouse_position().distance_to(goal) > 2.0:
			get_viewport().warp_mouse(get_global_transform_with_canvas() * goal)
			_parked = goal
		if _moving < 1.0:
			_moving = minf(_moving + delta / GLIDE, 1.0)
			var t := _moving
			var eased := 2.0 * t * t if t < 0.5 else 1.0 - 2.0 * (1.0 - t) * (1.0 - t)
			_at = _from.lerp(goal, eased)
		else:
			_at = goal
	_fired = minf(_fired + delta / FIRE, 1.0)
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
