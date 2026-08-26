# Port of jackal.Grenade.
#
# The grenade does not arc in world space: it travels in a straight line while
# its drawn scale follows a parabola, which is what sells the height.
class_name Grenade
extends GameElement

const DISTANCE := 320.0
const DISTANCE2 := 400.0
const MIN_SCALE := 0.6
const TRAVEL_TIME := 64
const HALF_TIME := TRAVEL_TIME / 2
const GRAVITY := -2.0 * (1.0 - MIN_SCALE) / float(HALF_TIME * HALF_TIME)
const VELOCITY := DISTANCE / TRAVEL_TIME
const VELOCITY2 := DISTANCE2 / TRAVEL_TIME
const HALF_GRAVITY := GRAVITY / 2.0
const V0 := -GRAVITY * HALF_TIME
const ANGULAR_VELOCITY := 10.0
const MARGIN := 21.0

var vx: float
var vy: float
var scale: float
var angle: float
var t: int
var enemies: Array[Enemy]


func _init(p_x: float, p_y: float, p_angle: int) -> void:
	super()
	x = p_x
	y = p_y

	var unit := main.create_unit_vector(p_angle)
	var v := VELOCITY2 if game_mode.player.long_range else VELOCITY
	vx = unit[0] * v
	vy = unit[1] * v

	enemies = game_mode.enemies
	main.play_sound(main.throw_sound)


func init() -> void:
	layer = 4


func update() -> void:
	x += vx
	y += vy
	scale = MIN_SCALE + t * (V0 + HALF_GRAVITY * t)
	angle += ANGULAR_VELOCITY

	var x1 := x - MARGIN
	var y1 := y - MARGIN
	var x2 := x + MARGIN
	var y2 := y + MARGIN
	var did_hit := false

	if not game_mode.is_outside_of_frame_rect(x1, y1, x2, y2):
		for i in range(enemies.size() - 1, -1, -1):
			var e: Enemy = enemies[i]
			if not e.remove and e.attack(x1, y1, x2, y2, AttackSource.PLAYER_WEAPON):
				did_hit = true
				break

	t += 1
	if did_hit or t > TRAVEL_TIME:
		do_remove()
		if not did_hit:
			main.play_explode_sound2()
		var e := Explosion.new(x, y)
		e.set_grenade_explosion(true)


func render() -> void:
	main.draw_angle_scale(main.grenade, x, y, angle, scale)
