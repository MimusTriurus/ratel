# Port of jackal.EnemyHelicopter: swoops in, hovers while shooting, then banks
# away off-screen. Shares the boss helicopter's hover-drift tables.
class_name EnemyHelicopter
extends Enemy

const APPEAR_DISTANCE := 192.0

const STATE_ENTERING := 0
const STATE_PAUSED := 1
const STATE_EXITING := 2

const ENTERING_TIME := 2 * 91
const PAUSED_TIME := 45
const ROTATION_TIME := 91

const ROTATION_ACCELERATION := 90.0 / float(ROTATION_TIME * ROTATION_TIME)
const TO_RADIANS := PI / 180.0

const SHOOT_DELAY := 68

const BULLET_SPEED := 1.75
const BULLET_TRAVEL_TIME := 91

var angle: float
var rotor_angle: float
var position_drift_time: int
var position_drift_dx: float
var position_drift_dy: float
var state: int = STATE_ENTERING
var entering_acceleration: float
var vy: float
var delay: int
var down: bool
var player: Player
var target_angle: float
var target_half_angle: float
var positive_angle: bool
var va: float
var v: float
var shoot_delay: int = SHOOT_DELAY


func _init(p_down: bool) -> void:
	super()
	x = game_mode.player.x \
		+ (-APPEAR_DISTANCE if main.random.randi_range(0, 1) == 0 else APPEAR_DISTANCE)
	if x - 96 < game_mode.camera_x:
		x = game_mode.player.x + APPEAR_DISTANCE
	elif x + 96 > game_mode.camera_x + Main.DISPLAY_WIDTH:
		x = game_mode.player.x - APPEAR_DISTANCE

	if p_down:
		angle = 90
		y = game_mode.camera_y - 60
	else:
		angle = 270
		y = game_mode.camera_y + Main.DISPLAY_HEIGHT + 60

	# Decelerate to a stop at mid-screen exactly at ENTERING_TIME.
	entering_acceleration = 2.0 * (y - (game_mode.camera_y
		+ 0.5 * Main.DISPLAY_HEIGHT)) / float(ENTERING_TIME * ENTERING_TIME)
	vy = -entering_acceleration * ENTERING_TIME

	down = p_down
	player = game_mode.player


func init() -> void:
	super.init()

	layer = 7

	hit_x1 = -24
	hit_y1 = -71
	hit_x2 = 24
	hit_y2 = 41

	points = 2000


func do_remove() -> void:
	remove = true
	main.stop_sound(main.helicopter_sound2)
	if play_sound_on_remove:
		main.play_hit_explode_sound()


func bullet_attack(_x1: float, _y1: float, _x2: float, _y2: float) -> bool:
	return false


func update() -> void:
	main.play_sound_if_not_playing(main.helicopter_sound2)

	shoot_delay -= 1
	if shoot_delay < 0:
		shoot_delay = SHOOT_DELAY
		var dx := player.x - x
		var dy := player.y - y
		var imag := BULLET_SPEED / sqrt(dx * dx + dy * dy)
		dx *= imag
		dy *= imag
		EnemyBullet.new(x + dx, y + dy, dx, dy, BULLET_TRAVEL_TIME,
			EnemyBullet.SPRITE_WHITE)

	position_drift_time -= 1
	if position_drift_time <= 0:
		position_drift_time = BossHelicopter.POSITION_DRIFT_TIME - 1
		var drift_angle := BossHelicopter.PI2 * main.random.randf()
		position_drift_dx = cos(drift_angle)
		position_drift_dy = sin(drift_angle)
	x += position_drift_dx * BossHelicopter.POSITIONS[position_drift_time]
	y += position_drift_dy * BossHelicopter.POSITIONS[position_drift_time]

	match state:
		STATE_ENTERING:
			var last_vy := vy
			vy += entering_acceleration
			y += vy
			if last_vy * vy <= 0:
				state = STATE_PAUSED
				delay = PAUSED_TIME
		STATE_PAUSED:
			delay -= 1
			if delay == 0:
				state = STATE_EXITING
				if down:
					entering_acceleration = -entering_acceleration
					if x > player.x:
						target_angle = 135.0
						target_half_angle = 112.5
						positive_angle = true
					else:
						target_angle = 45.0
						target_half_angle = 67.5
						positive_angle = false
				else:
					if x > player.x:
						target_angle = 225.0
						target_half_angle = 247.5
						positive_angle = false
					else:
						target_angle = 315.0
						target_half_angle = 292.5
						positive_angle = true
		STATE_EXITING:
			# Accelerate the bank up to the halfway angle, then brake into it.
			if angle != target_angle:
				angle += va
				if positive_angle:
					if angle >= target_half_angle:
						va -= ROTATION_ACCELERATION
						if va <= 0:
							angle = target_angle
					else:
						va += ROTATION_ACCELERATION
				else:
					if angle <= target_half_angle:
						va += ROTATION_ACCELERATION
						if va >= 0:
							angle = target_angle
					else:
						va -= ROTATION_ACCELERATION
			var ang := TO_RADIANS * angle
			v += entering_acceleration
			x += v * cos(ang)
			y += v * sin(ang)
			if game_mode.is_outside_of_frame_rect(x - 96, y - 96, x + 96, y + 96):
				play_sound_on_remove = false
				do_remove()


func check_bounds(_max_y: float) -> void:
	pass


func render() -> void:
	rotor_angle -= 30
	if rotor_angle == -90:
		rotor_angle = 0

	var ang: float = angle \
		- BossHelicopter.DRIFT_ANGLES[position_drift_time] * position_drift_dx

	main.draw_rotated_offset(main.enemy_helicopters[2], x + 32, y + 40, -30, -11, ang)
	main.draw_rotated_offset(main.enemy_helicopters[0], x, y, -74, -28, ang)

	for i in 4:
		main.draw_rotated_offset(main.enemy_helicopters[1], x, y, 0, -18,
			90 * i + rotor_angle)
