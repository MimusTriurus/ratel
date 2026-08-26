# Port of jackal.SwampMissileLauncher: a half-submerged silo. Only grenades and
# missile blasts can destroy it; bullets bounce off.
class_name SwampMissileLauncher
extends Enemy

const LAUNCH_DELAY := 3 * 91

# Ripple animation pattern for the idle water splash.
const SPLASH_INDICES: Array[bool] = [true, true, false, true, false, false]

var splash_index: int
var launch_delay: int
var splashing: int
var ready: bool


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	super.init()

	layer = 3

	bullet_hits = 4

	hit_x1 = 12
	hit_y1 = 4
	hit_x2 = 52
	hit_y2 = 28

	mine = true
	mine_x1 = 16
	mine_y1 = 8
	mine_x2 = 48
	mine_y2 = 24

	solid = true
	solid_x1 = 0
	solid_y1 = 0
	solid_x2 = 64
	solid_y2 = 32

	points = 2000

	explosion_x = 32
	explosion_y = 16


func update() -> void:
	if not ready:
		if not game_mode.is_outside_of_frame(x + 32, y):
			ready = true
		return

	if splashing > 0:
		splashing -= 1
	if launch_delay > 0:
		launch_delay -= 1
	elif not game_mode.is_outside_of_frame(x + 32, y + 16):
		launch_delay = LAUNCH_DELAY
		SwampMissile.new(x + 32, y + 16)
		splashing = 16


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if (attack_source == AttackSource.PLAYER_WEAPON
			or attack_source == AttackSource.TRAVELING_EXPLOSION) \
			and hit_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
		return true
	return false


func bullet_attack(_x1: float, _y1: float, _x2: float, _y2: float) -> bool:
	return false


func render() -> void:
	if splashing > 8:
		main.draw(main.swamp_missiles[4], x + 2, y)
	elif splashing > 0:
		main.draw(main.swamp_missiles[3], x + 16, y)
	else:
		splash_index += 1
		if splash_index == 6:
			splash_index = 0
		if SPLASH_INDICES[splash_index]:
			main.draw(main.swamp_missiles[2], x + 8, y)
		else:
			main.draw(main.swamp_missiles[1], x + 24, y)
