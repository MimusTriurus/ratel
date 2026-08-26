# Port of jackal.JeepYeahPlane: a silhouetted plane sweeping past the camera in
# the cutscene. Depth is a perspective divide on z; the plane fades in as it
# comes out of the distance.
class_name JeepYeahPlane
extends RefCounted

const CENTER_X := Main.DISPLAY_WIDTH / 2.0
const CENTER_Y := Main.DISPLAY_HEIGHT / 2.0

const Z1 := 2.0
const K1 := 2.0
const Z0 := (K1 * Z1) / (K1 - 1.0)

var x: float
var y: float
var z: float
var left: bool
var angle: float


func _init(p_left: bool) -> void:
	left = p_left

	if p_left:
		z = -8
		x = -650
		y = -300
	else:
		z = -15
		x = -950
		y = -400
		angle = -30


func update() -> void:
	z += 0.02
	if left:
		angle -= 0.1
	else:
		angle += 0.1


func render(main: Main) -> void:
	var k := Z0 / (Z0 - z)
	var fade_from := -7.0 if left else -14.0
	var alpha := (8.0 + z) if left else (15.0 + z)

	main.set_clip(0, 288, Main.DISPLAY_WIDTH, 416)
	if z < fade_from:
		main.draw_rotated_offset_scaled(main.black_plane,
			CENTER_X + k * x, CENTER_Y + k * y, -64, -20, angle, k, alpha)
	else:
		main.draw_rotated_offset_scaled(main.black_plane,
			CENTER_X + k * x, CENTER_Y + k * y, -64, -20, angle, k)
	main.clear_clip()
