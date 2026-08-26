# Port of jackal.GrayBoat: a gunboat that steams down the river, then holds
# station with a turret that keeps tracking the player.
class_name GrayBoat
extends Enemy

const SPRITE_TOGGLE_FRAMES := 12
const UPDATE_GUN_FRAMES := 4
const BULLET_DELAY := 91
const BULLET_TRAVEL_TIME := 2 * 91
const SPEED := 1.75
const MOVEMENT_TIME := 227
const TO_DEGREES := 180.0 / PI

var player: Player
var sprite_index: int
var sprite_index_counter: int
var bullet_delay: int
var movement_delay: int = MOVEMENT_TIME
var gun_angle: float
var update_gun: int


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	super.init()

	player = game_mode.player

	layer = 3

	bullet_hits = 8

	hit_x1 = 8
	hit_y1 = 8
	hit_x2 = 56
	hit_y2 = 184

	points = 800


func update() -> void:
	if movement_delay > 0:
		movement_delay -= 1
		y += SPEED

	sprite_index_counter -= 1
	if sprite_index_counter < 0:
		sprite_index_counter = SPRITE_TOGGLE_FRAMES
		sprite_index ^= 1

	update_gun -= 1
	if update_gun < 0:
		update_gun = UPDATE_GUN_FRAMES
		gun_angle = TO_DEGREES * atan2(player.y - (y + 131), player.x - (x + 32))

	bullet_delay -= 1
	if bullet_delay < 0:
		bullet_delay = BULLET_DELAY
		var X := x + 32
		var Y := y + 131
		var dx := player.x - X
		var dy := player.y - Y
		var imag := 1.0 / sqrt(dx * dx + dy * dy)
		dx *= imag
		dy *= imag
		EnemyBullet.new(X + 34 * dx, Y + 34 * dy, dx, dy, BULLET_TRAVEL_TIME,
			EnemyBullet.SPRITE_WHITE)


# The explosion is centred on the hull rather than on the origin.
func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if attack_source < AttackSource.PLAYER_EXPLOSION and hit_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x + 32, y + 96)
		main.add_points(points)
		return true
	return false


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	if not hit_rect(x1, y1, x2, y2):
		return false
	bullet_hits -= 1
	if bullet_hits <= 0:
		do_remove()
		Explosion.new(x + 32, y + 96)
		main.add_points(points)
	return true


func render() -> void:
	main.draw(main.gray_boats[sprite_index], x, y)
	main.draw_rotated_offset(main.gray_boats[2], x + 32, y + 131, -14, -13, gun_angle)
