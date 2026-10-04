# The shop's radar (docs/shop-plan.md): a mark at the edge of the 3D
# preview's frame for every enemy gun and tank off it, pointing at it --
# Level3DArrow's arrow, small, one for each, in the colour of the player who
# bought it. Not the original's, which has no shop; and nothing is drawn
# for what is in the frame. Only what is within REACH of the frame's middle:
# the whole stage's guns at once said nothing about which were near.
#
# On the HUD's layer, in its 2048x1152 layout, as the arrow is.
class_name Level3DRadar
extends Control

const OUTLINE := 3.0
const LENGTH := 24.0
const HALF_WIDTH := 13.0
const MARGIN := 34.0
const REACH := 26.0       # level metres from the frame's middle on the ground

var camera: Camera3D
var targets: Array[Vector3] = []
var colour := Color.WHITE
var shown := false
var bottom_inset := 0.0
var middle := Vector3.ZERO  # the frame's middle on the ground


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if not shown or camera == null:
		return
	var frame := Rect2(Vector2.ZERO, size)
	var centre := frame.get_center()
	var inner := frame.grow(-MARGIN)
	inner.size.y -= bottom_inset
	for target in targets:
		if Vector2(target.x - middle.x, target.z - middle.z).length() > REACH:
			continue
		var at := camera.unproject_position(target)
		if camera.is_position_behind(target):
			at = centre - (at - centre)
		elif frame.has_point(at):
			continue
		var dir := (at - centre).normalized()
		if dir == Vector2.ZERO:
			continue
		var reach := INF
		if dir.x != 0.0:
			reach = minf(reach, ((inner.end.x - centre.x) if dir.x > 0.0 else (centre.x - inner.position.x)) / absf(dir.x))
		if dir.y != 0.0:
			reach = minf(reach, ((inner.end.y - centre.y) if dir.y > 0.0 else (centre.y - inner.position.y)) / absf(dir.y))
		var tip := centre + dir * reach
		var side := dir.orthogonal()
		draw_colored_polygon(Level3DArrow._triangle(tip + dir * OUTLINE * 1.6, dir, side,
				LENGTH + OUTLINE * 2.6, HALF_WIDTH + OUTLINE * 1.6), Color.BLACK)
		draw_colored_polygon(Level3DArrow._triangle(tip, dir, side, LENGTH, HALF_WIDTH), colour)
