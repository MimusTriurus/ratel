# The 3D preview's reticle, in place of the system cursor while the mouse aims
# (Level3DSettings.Firing MODERN and COMBINED): the game's Main.draw_crosshair,
# four bars over a black pass grown round them, at the same sizes -- the HUD's
# 2048x1152 layout is the game's frame, so they come out as they do there.
#
# It owns the mouse mode, as Main._update_cursor_visibility does in the game:
# hidden while the reticle is drawn, visible otherwise, compared against the
# live Input.mouse_mode rather than a flag of its own. It keeps processing
# under the Escape menu, which pauses the tree, so that the menu gets the
# pointer back the frame it opens.
class_name Level3DCrosshair
extends Control

const UNIT := Main.CROSSHAIR_UNIT
const ARM := Main.CROSSHAIR_ARM
const GAP := Main.CROSSHAIR_GAP
const COLOUR := Main.CROSSHAIR_COLOR
const OUTLINE := Main.CROSSHAIR_OUTLINE

# `wanted.call()`: whether the reticle is drawn this frame.
var wanted: Callable
var _shown := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_shown = wanted.is_valid() and wanted.call()
	var mode := Input.MOUSE_MODE_HIDDEN if _shown else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode
	queue_redraw()


func _draw() -> void:
	if not _shown:
		return
	# Whole pixels, as the game's: a reticle between two would blur.
	var at := get_local_mouse_position().round()
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
