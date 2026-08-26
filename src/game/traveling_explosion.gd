# Port of jackal.TravelingExplosion.
class_name TravelingExplosion
extends GameElement

const DISTANCE := 320.0
const TRAVEL_TIME := 64
const PERIOD0 := TRAVEL_TIME / 3
const PERIOD1 := 2 * TRAVEL_TIME / 3
const VELOCITY := DISTANCE / TRAVEL_TIME
const ALPHA := 0.6

const K0 := 1.25 / float(PERIOD0)
const K1 := 0.75 / float(PERIOD1 - PERIOD0)
const K2 := 0.333 / float(TRAVEL_TIME - PERIOD1)

var vx: float
var vy: float
var notifier: bool
var t: int
var scale: float
var enemies: Array[Enemy]


func _init(p_x: float, p_y: float, p_vx: float, p_vy: float,
		p_notifier: bool) -> void:
	super()
	x = p_x
	y = p_y
	notifier = p_notifier
	vx = VELOCITY * p_vx
	vy = VELOCITY * p_vy
	enemies = game_mode.enemies


func init() -> void:
	layer = 4


func update() -> void:
	x += vx
	y += vy

	t += 1
	if t > TRAVEL_TIME:
		remove = true
		# Exactly one of the four blasts re-arms the weapon.
		if notifier:
			game_mode.player.set_weapon_armed(true)
		return

	var margin := 0.0
	if t < PERIOD0:
		scale = 2.25 - t * K0
		margin = 28 * scale
	elif t < PERIOD1:
		scale = 1.75 - (t - PERIOD0) * K1
		margin = 18 * scale
	else:
		scale = 1.333 - (t - PERIOD1) * K2
		margin = 16 * scale

	var x1 := x - margin
	var y1 := y - margin
	var x2 := x + margin
	var y2 := y + margin
	if not game_mode.is_outside_of_frame_rect(x1, y1, x2, y2):
		for i in range(enemies.size() - 1, -1, -1):
			var e: Enemy = enemies[i]
			if not e.remove:
				e.attack(x1, y1, x2, y2, AttackSource.TRAVELING_EXPLOSION)


func render() -> void:
	if t < PERIOD0:
		main.draw_scaled(main.explosions[1], x, y, scale, ALPHA)
	elif t < PERIOD1:
		main.draw_scaled(main.explosions[0], x, y, scale, ALPHA)
	else:
		main.draw_scaled(main.explosions[3], x, y, scale, ALPHA)
