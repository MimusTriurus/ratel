# Port of jackal.BossShipGun.
#
# One of the six turrets on the battleship deck. It stays shut until its
# manager triggers it, then opens, aims, fires a five-round fan and closes.
# Two grenade hits destroy it, but only one may land per opening.
class_name BossShipGun
extends Enemy

const STATE_CLOSED := 0
const STATE_OPENING := 1
const STATE_AIMING := 2
const STATE_SHOOTING := 3
const STATE_CLOSING := 4

const MIN_CLOSED_DELAY := 3 * 91
const MAX_CLOSED_DELAY := 6 * 91
const OPEN_DELAY := 85
const AIMING_DELAY := 40
const SHOOT_DELAY := 22

const SHOOT_SPREAD_ANGLE := PI / 9.0  # 20 degrees

const OPEN_SPEED := 32.0 / OPEN_DELAY

const BULLET_SPEED := 1.625
const BULLET_TRAVEL_TIME := 2 * 91

var player: Player
var state: int = STATE_CLOSED
var delay: int
var open_y: float
var angle: float
var aiming_speed: float
var color_index: int
var boss_ship_manager = null
var hits: int = 2
var was_hit: bool
var triggered: bool


func _init(p_x: float, p_y: float, p_manager) -> void:
	super()
	x = p_x
	y = p_y
	boss_ship_manager = p_manager
	delay = MIN_CLOSED_DELAY \
		+ main.random.randi_range(0, MAX_CLOSED_DELAY - MIN_CLOSED_DELAY - 1)


func init() -> void:
	super.init()

	player = game_mode.player

	layer = 3

	bullet_hits = 6

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
	match state:
		STATE_CLOSED:
			if triggered:
				delay -= 1
				if delay == 0:
					triggered = false
					state = STATE_OPENING
					open_y = 0
					delay = OPEN_DELAY
					was_hit = false
		STATE_OPENING:
			open_y += OPEN_SPEED
			if open_y > 32:
				open_y = 32
			delay -= 1
			if delay == 0 or open_y >= 32:
				state = STATE_AIMING
				angle = 90
				delay = AIMING_DELAY

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
						BULLET_TRAVEL_TIME, EnemyBullet.SPRITE_YELLOW)
					shoot_angle += SHOOT_SPREAD_ANGLE
		STATE_CLOSING:
			open_y -= OPEN_SPEED
			if open_y < 0:
				open_y = 0
			delay -= 1
			if delay == 0 or open_y <= 0:
				state = STATE_CLOSED
				delay = MIN_CLOSED_DELAY + main.random.randi_range(
					0, MAX_CLOSED_DELAY - MIN_CLOSED_DELAY - 1)


func open(p_delay: int) -> void:
	if state != STATE_CLOSED:
		return
	triggered = true
	delay = maxi(p_delay, 1)


func is_openable() -> bool:
	return not (remove or game_mode.is_outside_of_frame_rect(
		x + 8, y + 8, x + 56, y + 56))


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


func do_remove() -> void:
	remove = true
	main.add_points(points)
	main.play_hit_explode_sound()
	boss_ship_manager.gun_destroyed(self)


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if was_hit or not _vulnerable():
		return false
	if attack_source == AttackSource.PLAYER_WEAPON and hit_rect(x1, y1, x2, y2):
		was_hit = true
		Explosion.new(x + explosion_x, y + explosion_y)
		hits -= 1
		if hits == 0:
			do_remove()
		else:
			state = STATE_CLOSING
			delay = OPEN_DELAY
			main.play_hit_explode_sound()
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
	else:
		main.play_sound_always(main.bullet_hit_sound)
	return true


func render() -> void:
	match state:
		STATE_CLOSED:
			main.draw(main.ship_guns[1], x, y)
			main.draw(main.ship_guns[2], x, y + 32)
			main.draw(main.ship_guns[0], x, y)
		STATE_OPENING:
			main.set_clip(x, y, 64, 64)
			main.draw(main.floor_guns[4], x, y)
			main.draw(main.floor_guns[0], x + 3, y + 51 - open_y * 1.5)
			main.draw(main.ship_guns[1], x, y - open_y)
			main.draw(main.ship_guns[2], x, y + 32 + open_y)
			main.draw(main.ship_guns[0], x, y)
			main.clear_clip()
		STATE_AIMING:
			main.draw(main.floor_guns[4], x, y)
			main.draw(main.ship_guns[0], x, y)
			main.draw_rotated_offset(main.floor_guns[0], x + 32, y + 32,
				-29, -29, angle - 90)
		STATE_SHOOTING:
			color_index += 1
			if color_index == 4:
				color_index = 0
			main.draw(main.floor_guns[5 if color_index == 1 else 4], x, y)
			main.draw(main.ship_guns[0], x, y)
			main.draw_rotated_offset(main.floor_guns[color_index], x + 32, y + 32,
				-29, -29, angle - 90)
		STATE_CLOSING:
			main.set_clip(x, y, 64, 64)
			main.draw(main.floor_guns[4], x, y)
			main.draw_rotated_offset(main.floor_guns[0],
				x + 32, y + 32 + 48 - open_y * 1.5, -29, -29, angle - 90)
			main.draw(main.ship_guns[1], x, y - open_y)
			main.draw(main.ship_guns[2], x, y + 32 + open_y)
			main.draw(main.ship_guns[0], x, y)
			main.clear_clip()
