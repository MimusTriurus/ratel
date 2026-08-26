# Port of jackal.BossSuperTank.
#
# The final boss. It fades in, then shuttles left and right across the arena,
# stopping to fire a flame column. Fifteen grenades destroy it; every five
# changes its colour. Its death sequence runs for several seconds before the
# camera pans to the skull.
class_name BossSuperTank
extends Enemy

const STATE_APPEARING := 0
const STATE_ACCELERATING := 1
const STATE_MOVING := 2
const STATE_DECELERATING := 3
const STATE_STOPPED := 4
const STATE_EXPLODING := 5
const STATE_EXPLODING_FINISHING := 6
const STATE_EXPLODED := 7
const STATE_PANNING := 8
const STATE_FLASHING_SKULL := 9

const ACCELERATION_TIME := 23
const MAX_SPEED := 2.5
const ACCELERATION := MAX_SPEED / ACCELERATION_TIME

const FIRE_PROBABILITY := 0.75
const TARGET_PLAYER_PROBABILITY := 0.1

const WHEEL_ANGLE_CONST := 180.0 / (PI * 32.0)
const ANGLED_TREAD_ANGLE := 30.0
const ANGLED_TREAD_X := 0.8660254037844387   # cos(30 degrees)
const ANGLED_TREAD_Y := 0.49999999999999994  # sin(30 degrees)
const APPEARING_SCALE := 1.0 / 23.0

const HITS_ORANGE := 5
const HITS_RED := 10
const HITS_EXPLODE := 15

const EXPLODING_TIME := 460
const EXPLODING_FINISHING_TIME := 100
const INV_EXPLODING_TIME := 1.0 / float(EXPLODING_TIME)

# Distance covered while accelerating from rest to MAX_SPEED.
static var ACCELERATION_DISTANCE: float = 0.0

var player: Player
var color_index: int
var wheel_angle: float
var tread_offset: float
var state: int = STATE_APPEARING
var appearing_delay: int = 23
var vx: float
var target_x: float
var ax: float
var hits: int
var delay: int = 1
var smashed: float
var exploding: int
var super_fire: SuperFire


static func _static_init() -> void:
	var v := 0.0
	var d := 0.0
	while v < MAX_SPEED:
		v += ACCELERATION
		d += v
	ACCELERATION_DISTANCE = d


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y
	player = game_mode.player

	# The player's weapons reach further for this fight.
	player.long_range = true

	BossSuperTankGun.new(self)


func init() -> void:
	super.init()

	layer = 2

	hit_x1 = 0
	hit_y1 = 32
	hit_x2 = 456
	hit_y2 = 198

	points = 10000


# Mostly a random spot, but the more damaged it is the more often it aims for
# the player. The run is always long enough to reach full speed.
func _choose_target() -> void:
	state = STATE_ACCELERATING
	if main.random.randf() <= TARGET_PLAYER_PROBABILITY * color_index:
		target_x = player.x
	else:
		target_x = game_mode.camera_x + 48 \
			+ main.random.randi_range(0, Main.SCREEN_WIDTH - 96 - 1)
	if target_x < 176:
		target_x = 176
	elif target_x > 1872:
		target_x = 1872
	target_x -= 210
	if absf(x - target_x) < 3 * ACCELERATION_DISTANCE:
		if target_x + 210 < 1024:
			target_x = x + 3 * ACCELERATION_DISTANCE
		else:
			target_x = x - 3 * ACCELERATION_DISTANCE
	ax = -ACCELERATION if target_x < x else ACCELERATION


func _move(dx: float) -> void:
	x += dx
	wheel_angle += WHEEL_ANGLE_CONST * dx
	tread_offset -= dx
	while tread_offset < 0:
		tread_offset += 16
	while tread_offset >= 16:
		tread_offset -= 16


func _stop_moving() -> void:
	state = STATE_STOPPED
	if main.random.randf() <= FIRE_PROBABILITY:
		super_fire = SuperFire.new(x + 210, y + 314, self)
	delay = 91


func update() -> void:
	match state:
		STATE_APPEARING:
			appearing_delay -= 1
			if appearing_delay == 0:
				_choose_target()
				for i in 5:
					main.super_tanks[0][i].alpha = 1.0
		STATE_ACCELERATING:
			vx += ax
			_move(vx)
			if ax < 0:
				if vx <= -MAX_SPEED:
					state = STATE_MOVING
			else:
				if vx >= MAX_SPEED:
					state = STATE_MOVING
		STATE_MOVING:
			_move(vx)
			if absf(target_x - x) <= ACCELERATION_DISTANCE:
				state = STATE_DECELERATING
		STATE_DECELERATING:
			vx -= ax
			_move(vx)
			if ax < 0:
				if vx >= 0:
					_stop_moving()
			else:
				if vx <= 0:
					_stop_moving()
		STATE_STOPPED:
			delay -= 1
			if delay == 0:
				_choose_target()
		STATE_EXPLODING:
			delay -= 1
			if delay == 0:
				if exploding + 1 < EXPLODING_TIME:
					var e := Explosion.new(x + main.random.randi_range(0, 455),
						y + 32 + main.random.randi_range(0, 229))
					e.set_damages_enemies(false)
				delay = 8
			smashed = exploding * INV_EXPLODING_TIME
			exploding += 1
			if exploding == EXPLODING_TIME:
				state = STATE_EXPLODING_FINISHING
				exploding = EXPLODING_FINISHING_TIME
		STATE_EXPLODING_FINISHING:
			exploding -= 1
			if exploding == 0:
				main.request_song(main.cutscene_song)
				state = STATE_EXPLODED
				delay = 91
		STATE_EXPLODED:
			delay -= 1
			if delay == 0:
				state = STATE_PANNING
				game_mode.start_ending_camera_pan(self)


func _kaboom() -> void:
	state = STATE_EXPLODING
	main.stop_song()
	main.play_sound_always(main.headquarters_explodes_sound)
	main.add_points(points + 2000 * main.friendly_soldiers_picked_up)
	game_mode.destroy_all_except(self)
	delay = 1
	if super_fire != null:
		super_fire.do_remove()


# Three chains of delayed explosions climbing from the hit point to the roof,
# each tracking the tank as it keeps moving.
func _display_hit(hit_x: float, hit_y: float) -> void:
	if hit_y > y + 230:
		hit_y = y + 230

	for i in 3:
		var X := hit_x
		var Y := hit_y
		var d := 0
		while true:
			Explosion.attached(X, Y, true, d, 0.5, self)
			d += 2
			X += main.random.randi_range(0, 127) - 64
			if X < x:
				X = x + main.random.randi_range(0, 127)
			elif X > x + 456:
				X = x + 456 - main.random.randi_range(0, 127)
			Y -= 32
			if Y <= y + 32:
				break


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if state >= STATE_EXPLODING:
		return false
	if attack_source == AttackSource.PLAYER_WEAPON and hit_rect(x1, y1, x2, y2):
		hits += 1
		main.play_hit_explode_sound()
		if hits == HITS_EXPLODE:
			_kaboom()
		else:
			_display_hit(0.5 * (x1 + x2), 0.5 * (y1 + y2))
			if hits == HITS_ORANGE:
				color_index = 1
			elif hits == HITS_RED:
				color_index = 2
		return true
	return false


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	if state >= STATE_EXPLODING:
		return false
	return hit_rect(x1, y1, x2, y2)


func pan_complete() -> void:
	state = STATE_FLASHING_SKULL
	FlashingSkull.new()


func render() -> void:
	if state == STATE_APPEARING:
		for i in 5:
			main.super_tanks[0][i].alpha = 1.0 - appearing_delay * APPEARING_SCALE

	# The treads: two angled end sections and a straight run, each clipped to
	# its own housing and offset by the scroll.
	main.set_clip(x, y + 200, 64, 64)
	main.draw_rotated(main.super_tanks[color_index][0],
		x + 48 + ANGLED_TREAD_X * tread_offset,
		y + 219 + ANGLED_TREAD_Y * tread_offset,
		ANGLED_TREAD_ANGLE)
	main.set_clip(x + 400, y + 200, 50, 64)
	main.draw_rotated(main.super_tanks[color_index][0],
		x + 402 + ANGLED_TREAD_X * tread_offset,
		y + 227 - ANGLED_TREAD_Y * tread_offset,
		-ANGLED_TREAD_ANGLE)
	main.set_clip(x + 64, y + 200, 336, 64)
	for i in 6:
		main.draw(main.super_tanks[color_index][0],
			tread_offset + x + 32 + (i << 6), y + 200)
	main.clear_clip()

	for i in 6:
		main.draw_rotated(main.super_tanks[color_index][1],
			x + 72 + (i << 6), y + 216, wheel_angle)

	if state >= STATE_EXPLODING_FINISHING:
		main.draw(main.super_tanks[3][2], x + 160, y)
		main.draw(main.super_tanks[3][3], x, y + 32)
		main.draw(main.super_tanks[3][4], x + 192, y + 232)
	elif state == STATE_EXPLODING:
		# Cross-fade the intact hull into the smashed one.
		var alpha := 1.0 - smashed
		main.draw(main.super_tanks[2][2], x + 160, y, alpha)
		main.draw(main.super_tanks[2][3], x, y + 32, alpha)
		main.draw(main.super_tanks[2][4], x + 192, y + 232, alpha)
		main.draw(main.super_tanks[3][2], x + 160, y, smashed)
		main.draw(main.super_tanks[3][3], x, y + 32, smashed)
		main.draw(main.super_tanks[3][4], x + 192, y + 232, smashed)
	else:
		main.draw(main.super_tanks[color_index][2], x + 160, y)
		main.draw(main.super_tanks[color_index][3], x, y + 32)
		main.draw(main.super_tanks[color_index][4], x + 192, y + 232)
