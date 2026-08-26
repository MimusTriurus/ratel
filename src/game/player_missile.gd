# Port of jackal.PlayerMissile.
class_name PlayerMissile
extends GameElement

const DISTANCE := 360.0
const DISTANCE2 := 500.0
const TRAVEL_TIME := 32
const VELOCITY := DISTANCE / TRAVEL_TIME
const VELOCITY2 := DISTANCE2 / TRAVEL_TIME
const MARGIN := 21.0

var vx: float
var vy: float
var angle: float
var t: int
var power: int
var enemies: Array[Enemy]


func _init(p_x: float, p_y: float, p_angle: int, p_power: int) -> void:
	super()
	x = p_x
	y = p_y
	angle = p_angle
	power = p_power

	var unit := main.create_unit_vector(p_angle)
	var v := VELOCITY2 if game_mode.player.long_range else VELOCITY
	vx = unit[0] * v
	vy = unit[1] * v

	enemies = game_mode.enemies
	main.play_sound(main.missile_sound)


func init() -> void:
	layer = 4


func update() -> void:
	x += vx
	y += vy

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
	if did_hit or t > TRAVEL_TIME or game_mode.is_missile_target(x, y):
		remove = true
		if not did_hit:
			main.play_explode_sound3()
		var explosion := Explosion.new(x, y)
		# An unupgraded missile just explodes; upgrades throw the blast
		# sideways, and the second upgrade throws it vertically too.
		if power == 0:
			explosion.set_grenade_explosion(true)
		else:
			TravelingExplosion.new(x, y, -1, 0, true)
			TravelingExplosion.new(x, y, 1, 0, false)
			if power == 2:
				TravelingExplosion.new(x, y, 0, -1, false)
				TravelingExplosion.new(x, y, 0, 1, false)


func render() -> void:
	main.draw_rotated(main.player_missile, x, y, angle)
