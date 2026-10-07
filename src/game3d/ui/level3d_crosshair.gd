# The 3D preview's reticle, in place of the system cursor while the mouse aims
# (Level3DSettings.Firing MODERN and COMBINED): the game's Main.draw_crosshair,
# four bars over a black pass grown round them, at the same sizes -- the HUD's
# 2048x1152 layout is the game's frame, so they come out as they do there.
#
# And one at each of `points`, where the players on a pad aim with the right
# stick (level3d_preview.gd, _pad_reticles), the mouse's or not.
#
# It owns the mouse mode: the preview is played without the mouse, so the
# system pointer is hidden the whole time, compared against the live
# Input.mouse_mode rather than a flag of its own. It keeps processing under
# the Escape menu, which pauses the tree. The mouse's reticle is the modern
# firing's, hidden for now (Level3DSettings.MODERN_CONTROLS).
class_name Level3DCrosshair
extends Control

const UNIT := Main.CROSSHAIR_UNIT
const ARM := Main.CROSSHAIR_ARM
const GAP := Main.CROSSHAIR_GAP
const COLOUR := Main.CROSSHAIR_COLOR
const OUTLINE := Main.CROSSHAIR_OUTLINE

# `wanted.call()`: whether the mouse's reticle is drawn this frame.
var wanted: Callable
# `points.call()`: the pads' reticles, the viewport's positions.
var points: Callable
var _shown := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_shown = wanted.is_valid() and wanted.call()
	if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	queue_redraw()


func _draw() -> void:
	if _shown:
		_draw_reticle(get_local_mouse_position())
	if points.is_valid():
		var to_local := get_global_transform_with_canvas().affine_inverse()
		for p: Vector2 in points.call():
			_draw_reticle(to_local * p)


func _draw_reticle(where: Vector2) -> void:
	# Whole pixels, as the game's: a reticle between two would blur.
	var at := where.round()
	var half := UNIT * 0.5
	var bars: Array[Rect2] = [
		Rect2(at.x + GAP, at.y - half, ARM, UNIT),          # east
		Rect2(at.x - GAP - ARM, at.y - half, ARM, UNIT),    # west
		Rect2(at.x - half, at.y + GAP, UNIT, ARM),          # south
		Rect2(at.x - half, at.y - GAP - ARM, UNIT, ARM),    # north
	]
	for bar in bars:
		draw_rect(bar.grow(half), OUTLINE, true)
	for bar in bars:
		draw_rect(bar, COLOUR, true)
