# The sign that something is loading: the R.A.T.E.L. emblem, small, in the
# bottom right-hand corner, breathing in and out, as games put theirs there
# for the player to see the game has not hung. Level3DBoot puts it under its
# big still emblem; anything else that keeps the screen waiting can add one
# the same way and free it when done.
#
# Sizes are screen pixels, whatever the window: the viewport is 2048x1152
# stretched to it (project.godot), and this undoes the stretch.
class_name Level3DLoading
extends Control

const EMBLEM := preload("res://assets/images/ratel_emblem.png")
const SIZE := 96.0       # across, screen pixels
const MARGIN := 48.0     # from the frame's right and bottom edges
# Its opacity, between the two, the way a breath goes: slow at either end.
const LOW := 0.3
const HIGH := 1.0
const BREATH := 1.2      # seconds, in and out

var _time := 0.0


func _ready() -> void:
	# On over a paused tree, as the preview's title pauses it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var frame := get_viewport().get_visible_rect().size
	var window := Vector2(get_window().size)
	var shrink := minf(window.x / frame.x, window.y / frame.y)
	var side := SIZE / shrink
	var corner := frame - Vector2.ONE * (MARGIN / shrink)
	var breath := 0.5 - 0.5 * cos(_time * TAU / BREATH)
	draw_texture_rect(EMBLEM, Rect2(corner - Vector2.ONE * side, Vector2.ONE * side), false,
			Color(1, 1, 1, lerpf(LOW, HIGH, breath)))
