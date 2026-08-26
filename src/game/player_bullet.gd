# Port of jackal.PlayerBullet.
#
# The original always fires north; the angle is a port addition for mouse
# aiming. At the default 270 the unit vector is exactly (0, -1), so the
# keyboard path is unchanged.
class_name PlayerBullet
extends GameElement

const DISTANCE := 360.0
const TRAVEL_TIME := 20
const VELOCITY := DISTANCE / TRAVEL_TIME
const MARGIN := 16.0

var vx: float
var vy: float
var t: int
var enemies: Array[Enemy]


func _init(p_x: float, p_y: float, p_angle: float = 270.0) -> void:
	super()
	x = p_x
	y = p_y

	var unit := main.create_unit_vector_deg(p_angle)
	vx = unit[0] * VELOCITY
	vy = unit[1] * VELOCITY

	enemies = game_mode.enemies


func init() -> void:
	layer = 4
	main.play_sound_always(main.machine_gun_sound)


func update() -> void:
	x += vx
	y += vy

	var did_hit := false
	var x1 := x - MARGIN
	var y1 := y - MARGIN
	var x2 := x + MARGIN
	var y2 := y + MARGIN
	for i in range(enemies.size() - 1, -1, -1):
		var e: Enemy = enemies[i]
		if not e.remove and e.bullet_attack(x1, y1, x2, y2):
			did_hit = true
			break

	t += 1
	if did_hit or t > TRAVEL_TIME or game_mode.is_missile_target(x, y):
		remove = true
		BulletHit.new(x, y)


func render() -> void:
	main.draw_centered(main.yellow_bullet, x, y)
