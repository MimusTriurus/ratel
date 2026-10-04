# Port of jackal.CliffMissileLauncher: only grenades and missile blasts hurt it.
class_name CliffMissileLauncher
extends Enemy

const LAUNCH_DELAY := 3 * 91

var launch_delay: int
var ready: bool


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	super.init()

	layer = 3

	bullet_hits = 10

	hit_x1 = 8
	hit_y1 = 8
	hit_x2 = 88
	hit_y2 = 88

	points = 2000


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


func update() -> void:
	if not ready:
		if not game_mode.is_outside_of_frame(x + 48, y + 69):
			ready = true
		return

	if launch_delay > 0:
		launch_delay -= 1
	elif not game_mode.is_outside_of_frame(x + 48, y + 69):
		launch_delay = LAUNCH_DELAY
		SwampMissile.new(x + 48, y + 69)


func render() -> void:
	main.draw(main.cliff_missile_launcher, x, y)
