# The title's and the game over's mark on the entry picked (Level3DTitle,
# Level3DGameOverScreen): a bar behind the entry's words, in the sun's colour
# over the splash's dark, and a ▶ at its left before them -- the entry itself
# marked, as console menus mark it, rather than a pointer beside it. It took
# the place of the game's crosshair (Level3DReticle, gone with the mouse),
# and moves as that did: its owner aims it at an entry's words (aim) and it
# glides there over GLIDE seconds, eased; it breathes, the bar's fill and the
# ▶ a little, every BREATH seconds; and a pick flashes it (fire), over FIRE.
#
# Under the words: its owner adds it before the Control the words are drawn
# on. Whole pixels, as the font's are.
class_name Level3DSelection
extends Control

const COLOUR := Color(0.965, 0.627, 0.118)
const FLASH := Color(1.0, 0.93, 0.62)
const FILL := 0.2              # the bar's fill, breathing BREATH_FILL either way
const BREATH_FILL := 0.05
const EDGE := 0.55             # its frame's
const BREATH := 1.4
const GLIDE := 0.12
const FIRE := 0.3
# The bar round the words, of their height: PAD_X either side, PAD_Y above and
# below, and before them the ▶'s room, MARK_ROOM; the ▶ MARK tall, its point
# MARK_GAP before the words, nudged BREATH_NUDGE in and out.
const PAD_X := 0.45
const PAD_Y := 0.3
const MARK_ROOM := 1.2
const MARK := 0.75
const MARK_GAP := 0.5
const BREATH_NUDGE := 0.06

var shown := true

var _rect := Rect2()           # the words' it stands on now
var _from := Rect2()           # where its glide started
var _moving := 1.0             # 0 to 1 of its glide, 1 when it stands
var _target: Callable          # -> Rect2, the words' it is aimed at
var _time := 0.0
var _fired := 1.0              # 0 to 1 of a pick's flash, 1 when over


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


# To the words `target.call()` gives: gliding there, or put there at once.
func aim(target: Callable, glide := true) -> void:
	_target = target
	if glide:
		_from = _rect
		_moving = 0.0
	else:
		_moving = 1.0
		_rect = target.call()


# Opened: no pick flashing it.
func park() -> void:
	_fired = 1.0


func fire() -> void:
	_fired = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	if _target.is_valid():
		var goal: Rect2 = _target.call()
		if _moving < 1.0:
			_moving = minf(_moving + delta / GLIDE, 1.0)
			var t := _moving
			var eased := 2.0 * t * t if t < 0.5 else 1.0 - 2.0 * (1.0 - t) * (1.0 - t)
			_rect = Rect2(_from.position.lerp(goal.position, eased), _from.size.lerp(goal.size, eased))
		else:
			_rect = goal
	_fired = minf(_fired + delta / FIRE, 1.0)
	queue_redraw()


func _draw() -> void:
	if not shown or _rect.size.y <= 0.0:
		return
	var h := _rect.size.y
	var breath := sin(_time * TAU / BREATH)
	var flash := 1.0 - _fired
	var colour := COLOUR.lerp(FLASH, flash)
	var bar := Rect2(_rect.position.x - h * (PAD_X + MARK_ROOM), _rect.position.y - h * PAD_Y,
			_rect.size.x + h * (2.0 * PAD_X + MARK_ROOM), h * (1.0 + 2.0 * PAD_Y))
	bar = Rect2(bar.position.round(), bar.size.round())
	var fill := colour
	fill.a = FILL + BREATH_FILL * breath + 0.3 * flash
	draw_rect(bar, fill, true)
	var edge := colour
	edge.a = EDGE + 0.4 * flash
	draw_rect(bar, edge, false, maxf(roundf(h / 16.0), 1.0))
	# The ▶: its point MARK_GAP before the words, at their middle.
	var tall := roundf(h * MARK)
	var tip := Vector2(roundf(_rect.position.x - h * (MARK_GAP - BREATH_NUDGE * breath)),
			roundf(_rect.get_center().y))
	var mark := PackedVector2Array([tip, tip + Vector2(-tall * 0.8, -tall * 0.5), tip + Vector2(-tall * 0.8, tall * 0.5)])
	var outline := PackedVector2Array([tip + Vector2(2, 0), tip + Vector2(-tall * 0.8 - 2, -tall * 0.5 - 3),
			tip + Vector2(-tall * 0.8 - 2, tall * 0.5 + 3)])
	draw_colored_polygon(outline, Main.CROSSHAIR_OUTLINE)
	draw_colored_polygon(mark, colour)
