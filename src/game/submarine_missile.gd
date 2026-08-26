# Port of jackal.SubmarineMissile: fired along the nearest 45 degree heading
# towards the player and then flies straight.
class_name SubmarineMissile
extends Enemy

const SPEED := 8.0
const TO_DEGREES := 180.0 / PI

var vy: float
var vx: float
var tx: float
var ty: float
var angle: int
var explode_delay: int


func _init(p_x: float, p_y: float) -> void:
	super()
	var sy := p_y - 20

	var player := game_mode.player
	var ang := 180 + TO_DEGREES * atan2(sy - player.y, p_x - player.x)
	angle = 45 * roundi(ang / 45.0)
	var v := main.create_unit_vector(angle)
	vx = SPEED * v[0]
	vy = SPEED * v[1]
	tx = 18 * v[0]
	ty = 18 * v[1]

	x = p_x + v[0] * 24
	y = sy + v[1] * 24


func init() -> void:
	super.init()

	layer = 4

	bullet_hits = 1

	hit_x1 = -22
	hit_y1 = -22
	hit_x2 = 22
	hit_y2 = 22

	mine = true
	mine_x1 = -8
	mine_y1 = -8
	mine_x2 = 8
	mine_y2 = 8


func update() -> void:
	x += vx
	y += vy

	if game_mode.is_outside_of_frame_rect(x - 32, y - 32, x + 32, y + 32):
		play_sound_on_remove = false
		do_remove()


func render() -> void:
	main.draw_rotated(main.statue_missiles[0], x, y, angle)
