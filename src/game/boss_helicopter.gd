# Port of jackal.BossHelicopter.
#
# Drops in, hovers, releases four paratroopers, banks away out of the top of
# the screen and comes back somewhere else. Seven grenades kill it. Every hit
# shakes it sideways and runs a string of small explosions along the fuselage.
#
# The drift, entry, and shake motions are all baked into per-tick delta tables
# so that the paths are exactly repeatable.
class_name BossHelicopter
extends Enemy

const STATE_ENTERING := 0
const STATE_HOVERING := 1
const STATE_RELEASING := 2
const STATE_LEAVING := 3
const STATE_HIDDEN := 4

const HITS := 7
const POSITION_DRIFT_TIME := (2 * 91) + 1
const POSITION_DRIFT_DISTANCE := 32.0
const PI2 := 2.0 * PI
const DRIFT_ANGLE := 5.0
const MIN_Y := -96.0
const MIN_Y2 := -256.0
const MAX_Y := 480.0
const ENTERING_TIME := 2 * 91
const HOVER_TIME := 45
const RELEASING_TIME_MIN := 23
const RELEASING_TIME_MAX := 45
const HIDDEN_TIME := 91
const ROTATE_TIME := 2 * 91
const ROTATE_HALF_TIME := ROTATE_TIME / 2.0
const ROTATE_ACCELERATION := 180.0 / (ROTATE_HALF_TIME * ROTATE_HALF_TIME)
const MAX_APPEAR_DISTANCE := 128
const TO_RADIANS := PI / 180.0
const SHUTTER_TIME := 91
const SHUTTER_AMPLITUDE := 8.0
const SHUTTER_CYCLES := 5.0
const MAX_SOLDIERS := 32
const BULLET_DELAY := 68
const BULLET_SPEED := 1.75
const BULLET_TRAVEL_TIME := 91

static var POSITIONS: PackedFloat32Array = PackedFloat32Array()
static var DRIFT_ANGLES: PackedFloat32Array = PackedFloat32Array()
static var ENTERINGS: PackedFloat32Array = PackedFloat32Array()
static var SHUTTERS: PackedFloat32Array = PackedFloat32Array()
static var ENTER_ACCELERATION: float = 0.0

var player: Player
var angle: float
var rotor_angle: float
var tail_index_counter: bool
var tail_index: int
var position_drift_time: int
var position_drift_dx: float
var position_drift_dy: float
var delay: int
var state: int = STATE_ENTERING
var vy: float
var va: float
var rotate_cw: bool
var hits: int
var tiny_explosions: int
var tiny_explosions_delay: int
var shuttering: int
var parachutes: int
var soldiers: int
var bullet_delay: int


static func _static_init() -> void:
	POSITIONS.resize(POSITION_DRIFT_TIME)
	DRIFT_ANGLES.resize(POSITION_DRIFT_TIME)
	ENTERINGS.resize(ENTERING_TIME)
	SHUTTERS.resize(SHUTTER_TIME)

	# Hover drift: accelerate for half the cycle, decelerate for the other half.
	var xs := PackedFloat32Array()
	xs.resize(POSITION_DRIFT_TIME + 1)
	var half_time := POSITION_DRIFT_TIME / 2
	var T := float(half_time)
	var a := POSITION_DRIFT_DISTANCE / (T * T)
	for i in range(half_time + 1):
		xs[i] = 0.5 * a * i * i
		xs[POSITION_DRIFT_TIME - i - 1] = POSITION_DRIFT_DISTANCE - xs[i]
	for i in POSITION_DRIFT_TIME:
		POSITIONS[i] = xs[i + 1] - xs[i]
		var ang := 2 * PI * i / float(POSITION_DRIFT_TIME) - PI
		DRIFT_ANGLES[i] = DRIFT_ANGLE * (0.5 + 0.5 * cos(ang))
	POSITIONS[POSITION_DRIFT_TIME - 1] = 0

	# Entry: decelerate from off-screen to a stop at MAX_Y.
	var n := ENTERING_TIME + 1
	xs = PackedFloat32Array()
	xs.resize(n)
	ENTER_ACCELERATION = 2.0 * (MAX_Y - MIN_Y) / float(n * n)
	for i in n:
		var t := n - 1 - i
		xs[i] = MAX_Y - 0.5 * ENTER_ACCELERATION * t * t
	for i in ENTERING_TIME:
		ENTERINGS[i] = xs[i + 1] - xs[i]

	# Hit shake: a decaying sine, stored backwards as per-tick deltas.
	n = SHUTTER_TIME + 1
	xs = PackedFloat32Array()
	xs.resize(n)
	for i in n:
		xs[i] = ((n - 1 - i) * SHUTTER_AMPLITUDE / float(n)) \
			* sin(i * 2 * PI * SHUTTER_CYCLES / float(n))
	for i in SHUTTER_TIME:
		SHUTTERS[SHUTTER_TIME - 1 - i] = xs[i + 1] - xs[i]


func init() -> void:
	super.init()

	player = game_mode.player

	layer = 6

	hit_x1 = -24
	hit_y1 = -40
	hit_x2 = 24
	hit_y2 = 80

	points = 5000

	_randomize_location()


func _randomize_location() -> void:
	y = MIN_Y
	x = player.x + main.random.randi_range(0, 2 * MAX_APPEAR_DISTANCE - 1) \
		- MAX_APPEAR_DISTANCE
	if x < 672:
		x = 672
	elif x > 1376:
		x = 1376
	hit_x1 = -24
	hit_y1 = -40
	hit_x2 = 24
	hit_y2 = 80


func _fuselage_direction() -> Vector2:
	var ang: float = TO_RADIANS * (angle + 90
		- DRIFT_ANGLES[position_drift_time] * position_drift_dx)
	return Vector2(cos(ang), sin(ang))


func update() -> void:
	if state != STATE_HIDDEN:
		main.play_sound_if_not_playing(main.helicopter_sound2)

	bullet_delay -= 1
	if bullet_delay < 0:
		bullet_delay = BULLET_DELAY
		var dx := player.x - x
		var dy := player.y - y
		var imag := BULLET_SPEED / sqrt(dx * dx + dy * dy)
		dx *= imag
		dy *= imag
		EnemyBullet.new(x + dx, y + dy, dx, dy, BULLET_TRAVEL_TIME,
			EnemyBullet.SPRITE_WHITE)

	if tiny_explosions > 0:
		tiny_explosions_delay -= 1
		if tiny_explosions_delay <= 0:
			var d := _fuselage_direction()
			var dist := tiny_explosions * 40 - 232
			var explosion := Explosion.new(x + dist * d.x, y + dist * d.y)
			explosion.set_tiny(true)
			explosion.change_layer(7)
			explosion.set_alpha(0.5)
			tiny_explosions_delay = 4
			tiny_explosions -= 1

	if shuttering > 0:
		shuttering -= 1
		x += SHUTTERS[shuttering]

	position_drift_time -= 1
	if position_drift_time <= 0:
		position_drift_time = POSITION_DRIFT_TIME - 1
		var drift_angle := PI2 * main.random.randf()
		position_drift_dx = cos(drift_angle)
		position_drift_dy = sin(drift_angle)
	x += position_drift_dx * POSITIONS[position_drift_time]
	y += position_drift_dy * POSITIONS[position_drift_time]

	match state:
		STATE_ENTERING:
			y += ENTERINGS[delay]
			delay += 1
			if delay == ENTERING_TIME:
				state = STATE_HOVERING
				delay = 0
		STATE_HOVERING:
			delay += 1
			if delay == HOVER_TIME:
				state = STATE_RELEASING
				delay = 0
		STATE_RELEASING:
			delay -= 1
			if delay <= 0:
				var n := parachutes
				parachutes += 1
				if n == 3:
					state = STATE_LEAVING
					delay = 0
					vy = 0
					va = 0
					rotate_cw = main.random.randi_range(0, 1) == 0
					parachutes = 0
				else:
					if soldiers < MAX_SOLDIERS:
						Parachute.new(x, y - 32, (1 + parachutes) * 64,
							x > 1024, self)
						soldiers += 1
					delay = RELEASING_TIME_MIN + main.random.randi_range(
						0, RELEASING_TIME_MAX - RELEASING_TIME_MIN - 1)
		STATE_LEAVING:
			_update_leaving()
		STATE_HIDDEN:
			delay += 1
			if delay == HIDDEN_TIME:
				delay = 0
				state = STATE_ENTERING
				_randomize_location()
				angle = 0


# While banking, the hit box shrinks as the helicopter turns side-on.
func _update_leaving() -> void:
	vy += ENTER_ACCELERATION
	y -= vy
	if y < MIN_Y2:
		delay = 0
		state = STATE_HIDDEN
		main.stop_sound(main.helicopter_sound2)

	if rotate_cw:
		if angle > 68 and angle < 112:
			hit_x1 = -24
			hit_y1 = -32
			hit_x2 = 24
			hit_y2 = 32
		else:
			hit_x1 = -24
			hit_y1 = -80
			hit_x2 = 24
			hit_y2 = 40
		if angle < 90:
			va += ROTATE_ACCELERATION
			angle += va
		elif angle < 180:
			va -= ROTATE_ACCELERATION
			angle += va
		else:
			angle = 180
	else:
		if angle < -68 and angle > -112:
			hit_x1 = -24
			hit_y1 = -32
			hit_x2 = 24
			hit_y2 = 32
		else:
			hit_x1 = -24
			hit_y1 = -80
			hit_x2 = 24
			hit_y2 = 40
		if angle > -90:
			va += ROTATE_ACCELERATION
			angle -= va
		elif angle > -180:
			va -= ROTATE_ACCELERATION
			angle -= va
		else:
			angle = -180
			hit_x1 = -24
			hit_y1 = -80
			hit_x2 = 24
			hit_y2 = 40


func bump(_x1: float, _y1: float, _x2: float, _y2: float,
		_invincible: bool) -> bool:
	return false


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if tiny_explosions != 0 or attack_source != AttackSource.PLAYER_WEAPON \
			or not hit_rect(x1, y1, x2, y2):
		return false

	main.play_hit_explode_sound()
	hits += 1
	if hits == HITS:
		main.stop_sound(main.helicopter_sound2)
		do_remove()
		var d := _fuselage_direction()
		for i in 4:
			var dist := i * 80 - 232
			var e := Explosion.new(x + dist * d.x, y + dist * d.y)
			e.set_delayed(3 * (3 - i))
		main.add_points(points)
		game_mode.destroy_all()
		game_mode.mark_stage_completed()

	tiny_explosions = 8
	tiny_explosions_delay = 0
	shuttering = SHUTTER_TIME
	return true


func soldier_killed() -> void:
	soldiers -= 1


func bullet_attack(_x1: float, _y1: float, _x2: float, _y2: float) -> bool:
	return false


func check_bounds(_max_y: float) -> void:
	pass


func render() -> void:
	rotor_angle -= 30
	if rotor_angle == -90:
		rotor_angle = 0
	tail_index_counter = not tail_index_counter
	if tail_index_counter:
		tail_index = 4 if tail_index == 3 else 3

	var ang: float = angle - DRIFT_ANGLES[position_drift_time] * position_drift_dx

	main.draw_rotated_offset(main.boss_helicopters[5], x + 64, y + 64, -18, -65, ang)
	main.draw_rotated_offset(main.boss_helicopters[0], x, y, -64, -232, ang)
	main.draw_rotated_offset(main.boss_helicopters[1], x, y, 0, -232, ang)
	main.draw_rotated_offset(main.boss_helicopters[tail_index], x, y, -16, -224, ang)
	for i in 4:
		main.draw_rotated_offset(main.boss_helicopters[2], x, y, 0, -32,
			90 * i + rotor_angle)
