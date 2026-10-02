# An arrow at the edge of the 3D preview's frame, pointing at a place in the
# level that is off it: the rescue helicopter's pad while there are prisoners
# aboard for it (level3d_preview.gd, _update_pad_arrow). Not the original's --
# the NES's pad is never more than a scroll away and its frame never tilts --
# and so off with the rest of the HUD (Level3DSettings.hud_pad_arrow).
#
# Drawn on the HUD's layer, in its 2048x1152 layout, which is also what the
# camera projects into: the window's content is scaled as canvas items
# (level3d_preview.gd, _apply_resolution), so the viewport's own size stays the
# layout's however big the window is. Nothing is drawn while the place is in
# the frame.
class_name Level3DArrow
extends Control

const COLOUR := Color(1.0, 0.8, 0.3)
const OUTLINE := 5.0      # layout px of black round it, as the HUD's text has
const LENGTH := 44.0      # tip to base, layout px
const HALF_WIDTH := 26.0
const MARGIN := 56.0      # from the frame's edge to the tip

var camera: Camera3D
var target := Vector3.ZERO
var shown := false
# Layout px along the bottom edge that are the HUD's line, kept clear as well.
var bottom_inset := 0.0


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
	var at := camera.unproject_position(target)
	# Behind a tilted camera the projection comes out mirrored through the
	# centre; mirrored back, it points the right way.
	if camera.is_position_behind(target):
		at = centre - (at - centre)
	elif frame.has_point(at):
		return
	var dir := (at - centre).normalized()
	if dir == Vector2.ZERO:
		return
	# Where the line from the centre leaves the frame, MARGIN in from its edge
	# and the HUD's line.
	var reach := INF
	if dir.x != 0.0:
		reach = minf(reach, ((inner.end.x - centre.x) if dir.x > 0.0 else (centre.x - inner.position.x)) / absf(dir.x))
	if dir.y != 0.0:
		reach = minf(reach, ((inner.end.y - centre.y) if dir.y > 0.0 else (centre.y - inner.position.y)) / absf(dir.y))
	var tip := centre + dir * reach
	var side := dir.orthogonal()
	draw_colored_polygon(_triangle(tip + dir * OUTLINE * 1.6, dir, side,
			LENGTH + OUTLINE * 2.6, HALF_WIDTH + OUTLINE * 1.6), Color.BLACK)
	draw_colored_polygon(_triangle(tip, dir, side, LENGTH, HALF_WIDTH), COLOUR)


static func _triangle(tip: Vector2, dir: Vector2, side: Vector2, length: float,
		half_width: float) -> PackedVector2Array:
	var base := tip - dir * length
	return PackedVector2Array([tip, base + side * half_width, base - side * half_width])
