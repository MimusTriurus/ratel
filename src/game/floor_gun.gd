# Port of jackal.FloorGun.
#
# A gun hidden under a floor panel: the panel slides apart, the gun rises,
# aims, fires a five-round fan and closes again. It is only vulnerable while
# the panel is more than half open.
class_name FloorGun
extends Enemy

const STATE_CLOSED := 0
const STATE_OPENING := 1
const STATE_AIMING := 2
const STATE_SHOOTING := 3
const STATE_CLOSING := 4

const CLOSED_DELAY := 2 * 91
const OPEN_DELAY := 85
const AIMING_DELAY := 40
const SHOOT_DELAY := 22

const SHOOT_SPREAD_ANGLE := PI / 9.0  # 20 degrees

const OPEN_SPEED := 32.0 / OPEN_DELAY

const BULLET_SPEED := 1.625
const BULLET_TRAVEL_TIME := 2 * 91

var player: Player
var state: int = STATE_CLOSED
var delay: int = 1
var open_y: float
var angle: float
var aiming_speed: float
var color_index: int
var ready: bool
var mask: Spr
var panel: Spr


func _init(p_x: float, p_y: float, plain: bool = false) -> void:
	super()
	x = p_x
	y = p_y
	if plain:
		mask = main.plain_floor_guns[0]
		panel = main.plain_floor_guns[1]
	else:
		mask = main.floor_guns[6]
		panel = main.floor_guns[7]


func init() -> void:
	super.init()

	player = game_mode.player

	layer = 3

	bullet_hits = 4

	hit_x1 = 4
	hit_y1 = 4
	hit_x2 = 60
	hit_y2 = 60

	mine = true
	mine_x1 = 8
	mine_y1 = 8
	mine_x2 = 56
	mine_y2 = 56

	solid = true
	solid_x1 = 0
	solid_y1 = 0
	solid_x2 = 64
	solid_y2 = 64

	points = 1000

	explosion_x = 32
	explosion_y = 32


func update() -> void:
	if not ready:
		if not game_mode.is_outside_of_frame(x + 32, y + 32):
			ready = true
		else:
			return

	match state:
		STATE_CLOSED:
			delay -= 1
			if delay == 0:
				state = STATE_OPENING
				open_y = 0
				delay = OPEN_DELAY
		STATE_OPENING:
			open_y += OPEN_SPEED
			delay -= 1
			if delay == 0:
				state = STATE_AIMING
				angle = 90
				delay = AIMING_DELAY

				# Spread the swing towards the player evenly over the aim time.
				var target_angle := rad_to_deg(atan2(player.y - y, player.x - x))
				var delta_angle := fmod(target_angle + 90, 360.0)
				if delta_angle < 0:
					delta_angle += 180
				else:
					delta_angle -= 180

				aiming_speed = delta_angle / AIMING_DELAY
		STATE_AIMING:
			angle += aiming_speed
			delay -= 1
			if delay == 0:
				state = STATE_SHOOTING
				delay = SHOOT_DELAY
		STATE_SHOOTING:
			delay -= 1
			if delay == 0:
				state = STATE_CLOSING
				delay = OPEN_DELAY
				open_y = 32

				var shoot_angle := atan2(player.y - (y + 32), player.x - (x + 32))
				shoot_angle -= 2 * SHOOT_SPREAD_ANGLE

				for i in 5:
					var c := cos(shoot_angle)
					var s := sin(shoot_angle)
					EnemyBullet.new(x + 32 + 13 * c, y + 32 + 13 * s,
						BULLET_SPEED * c, BULLET_SPEED * s,
						BULLET_TRAVEL_TIME, EnemyBullet.SPRITE_WHITE)
					shoot_angle += SHOOT_SPREAD_ANGLE
		STATE_CLOSING:
			open_y -= OPEN_SPEED
			delay -= 1
			if delay == 0:
				state = STATE_CLOSED
				delay = CLOSED_DELAY


func _vulnerable() -> bool:
	return state != STATE_CLOSED and open_y >= 16


func bump(x1: float, y1: float, x2: float, y2: float, invincible: bool) -> bool:
	if invincible or not _vulnerable():
		return false
	if is_mine_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
		return true
	return false


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if not _vulnerable():
		return false
	if attack_source < AttackSource.PLAYER_EXPLOSION and hit_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
		return true
	return false


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	if not _vulnerable():
		return false
	if not hit_rect(x1, y1, x2, y2):
		return false
	bullet_hits -= 1
	if bullet_hits <= 0:
		do_remove()
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
	else:
		main.play_sound_always(main.bullet_hit_sound)
	return true


func render() -> void:
	match state:
		STATE_CLOSED:
			main.draw(panel, x, y)
			main.draw(panel, x, y + 32)
			main.draw(mask, x, y)
		STATE_OPENING:
			main.set_clip(x, y, 64, 64)
			main.draw(main.floor_guns[4], x, y)
			main.draw(main.floor_guns[0], x + 3, y + 51 - open_y * 1.5)
			main.draw(panel, x, y - open_y)
			main.draw(panel, x, y + 32 + open_y)
			main.draw(mask, x, y)
			main.clear_clip()
		STATE_AIMING:
			main.draw(main.floor_guns[4], x, y)
			main.draw(mask, x, y)
			main.draw_rotated_offset(main.floor_guns[0], x + 32, y + 32,
				-29, -29, angle - 90)
		STATE_SHOOTING:
			color_index += 1
			if color_index == 4:
				color_index = 0
			main.draw(main.floor_guns[5 if color_index == 1 else 4], x, y)
			main.draw(mask, x, y)
			main.draw_rotated_offset(main.floor_guns[color_index], x + 32, y + 32,
				-29, -29, angle - 90)
		STATE_CLOSING:
			main.set_clip(x, y, 64, 64)
			main.draw(main.floor_guns[4], x, y)
			main.draw_rotated_offset(main.floor_guns[0],
				x + 32, y + 32 + 48 - open_y * 1.5, -29, -29, angle - 90)
			main.draw(panel, x, y - open_y)
			main.draw(panel, x, y + 32 + open_y)
			main.draw(mask, x, y)
			main.clear_clip()
