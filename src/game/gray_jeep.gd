# Port of jackal.GrayJeep.
#
# Faster than the tanks, turns 45 degrees at a time rather than snapping to a
# new heading, and drops bombs behind itself instead of shooting.
class_name GrayJeep
extends Enemy

const SPEED := 3.0
const SENSOR_RADIUS := 53.0
const ANGLE_STEPS := 16
const ANGLE_VELOCITY := 45.0 / ANGLE_STEPS
const BOMB_DELAY := 91
const BULLET_TRAVEL_TIME := 2 * 91

const MAX_MOVE_SQUARES := 8

const DIMENSION_1 := 48.0
const DIMENSION_2 := 32.0

var bomb_delay: int
var move_steps: int
var target_angle: int = 90
var display_angle: float = 90
var direction_x: float
var direction_y: float
var vx: float
var vy: float
var sensor_x: float
var sensor_y: float
var last_dx: float
var last_dy: float
var solids: Array[Enemy]
var player: Player
var handling_loop: int
var loop_target_x: float
var loop_target_y: float


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	super.init()

	solids = game_mode.solids
	player = game_mode.player

	layer = 3

	bullet_hits = 2

	hit_x1 = -40
	hit_y1 = -40
	hit_x2 = 40
	hit_y2 = 40

	mine = true
	mine_x1 = -28
	mine_y1 = -28
	mine_x2 = 28
	mine_y2 = 28

	solid = true
	solid_x1 = -48
	solid_y1 = -48
	solid_x2 = 48
	solid_y2 = 48

	points = 800


func _compute_move_steps() -> void:
	var v := direction_x if direction_x != 0 else direction_y
	if v == 0:
		return

	var d := 32 - fmod(v, 32.0) if v > 0 else fmod(v, 32.0)
	d += 32 * (1 + main.random.randi_range(0, MAX_MOVE_SQUARES - 1))

	move_steps = roundi(d / SPEED)

func _drive_at_right_angle_to_barrier() -> void:
	var Vx := vx
	var Vy := vy
	var Dx := direction_x
	var Dy := direction_y

	if main.random.randi_range(0, 4) == 4:
		vx = -vx
		vy = -vy
		direction_x = -direction_x
		direction_y = -direction_y
		target_angle += 180
	elif main.random.randi_range(0, 2) == 2:
		vx = Vy
		vy = -Vx
		direction_x = Dy
		direction_y = -Dx
		target_angle -= 90
	else:
		vx = -Vy
		vy = Vx
		direction_x = -Dy
		direction_y = Dx
		target_angle += 90

	if target_angle >= 360:
		target_angle -= 360
	elif target_angle < 0:
		target_angle += 360
	sensor_x = direction_x * SENSOR_RADIUS
	sensor_y = direction_y * SENSOR_RADIUS

	if main.random.randi_range(0, 4) != 4:
		_compute_move_steps()


func _test_corners(next_x: float, next_y: float) -> void:
	var sx1 := 0.0
	var sy1 := 0.0
	var sx2 := 0.0
	var sy2 := 0.0

	match target_angle:
		0:
			sx1 = next_x + DIMENSION_1
			sy1 = next_y - DIMENSION_2
			sx2 = next_x + DIMENSION_1
			sy2 = next_y + DIMENSION_2
		90:
			sx1 = next_x + DIMENSION_2
			sy1 = next_y + DIMENSION_1
			sx2 = next_x - DIMENSION_2
			sy2 = next_y + DIMENSION_1
		180:
			sx1 = next_x - DIMENSION_1
			sy1 = next_y + DIMENSION_2
			sx2 = next_x - DIMENSION_1
			sy2 = next_y - DIMENSION_2
		270:
			sx1 = next_x - DIMENSION_2
			sy1 = next_y - DIMENSION_1
			sx2 = next_x + DIMENSION_2
			sy2 = next_y - DIMENSION_1
		_:
			return

	var drive1 := game_mode.is_driveable(sx1, sy1)
	var drive2 := game_mode.is_driveable(sx2, sy2)
	if drive1 and drive2:
		return

	if not (drive1 or drive2):
		_drive_at_right_angle_to_barrier()
		return

	var Vx := vx
	var Vy := vy
	var Dx := direction_x
	var Dy := direction_y

	if drive2:
		vx = -Vy
		vy = Vx
		direction_x = -Dy
		direction_y = Dx
		target_angle += 90
	else:
		vx = Vy
		vy = -Vx
		direction_x = Dy
		direction_y = -Dx
		target_angle -= 90

	if target_angle >= 360:
		target_angle -= 360
	elif target_angle < 0:
		target_angle += 360
	sensor_x = direction_x * SENSOR_RADIUS
	sensor_y = direction_y * SENSOR_RADIUS

	if main.random.randi_range(0, 4) != 4:
		_compute_move_steps()


func _handle_loop() -> void:
	if handling_loop == 0:
		handling_loop = 91 * (2 + main.random.randi_range(0, 4))
		loop_target_x = main.random.randf() * 2048
		loop_target_y = main.random.randf() * player.y

func update() -> void:
	if display_angle != target_angle:
		var delta_angle := fmod(target_angle - display_angle + 180, 360.0)
		if delta_angle < 0:
			delta_angle += 180
		else:
			delta_angle -= 180
		if absf(delta_angle) < ANGLE_VELOCITY:
			display_angle = target_angle
		elif delta_angle < 0:
			display_angle -= ANGLE_VELOCITY
		else:
			display_angle += ANGLE_VELOCITY
		return

	if handling_loop > 0:
		handling_loop -= 1

	move_steps -= 1
	if move_steps <= 0:
		var dx := 0
		var dy := 0
		if main.random.randi_range(0, 4) == 4:
			dx = main.random.randi_range(0, 511) - 256
			dy = main.random.randi_range(0, 511) - 256
		var v: PackedFloat32Array
		if handling_loop > 0:
			v = game_mode.suggest_direction_turning(x, y, loop_target_x + dx,
				loop_target_y + dy, target_angle, false)
		else:
			v = game_mode.suggest_direction_turning(x, y, player.x + dx,
				player.y + dy, target_angle, false)
		vx = v[0] * SPEED
		vy = v[1] * SPEED
		direction_x = v[0]
		direction_y = v[1]
		target_angle = int(v[2])
		sensor_x = direction_x * SENSOR_RADIUS
		sensor_y = direction_y * SENSOR_RADIUS
		_compute_move_steps()

	var next_x := x + vx
	var next_y := y + vy

	if game_mode.conveyor_delta > 0 and game_mode.is_conveyor(x, y):
		next_y += game_mode.conveyor_delta

	_test_corners(next_x, next_y)

	var driveable := true

	if game_mode.is_driveable(next_x + sensor_x, next_y + sensor_y):
		for i in range(solids.size() - 1, -1, -1):
			var s: Enemy = solids[i]
			if s != self and s.is_solid_rect(next_x + solid_x1, next_y + solid_y1,
					next_x + solid_x2, next_y + solid_y2) \
					and not s.is_solid_rect(x + solid_x1, y + solid_y1,
						x + solid_x2, y + solid_y2):
				driveable = false
				break
	else:
		driveable = false

	if driveable:
		x = next_x
		y = next_y
		update_trail()
		if trail_contains_loop():
			_handle_loop()
	else:
		_drive_at_right_angle_to_barrier()

	var dx := player.x - x
	var dy := player.y - y

	if move_steps == 1 and ((vy != 0 and int(player.x) >> 7 == int(x) >> 7)
			or (vx != 0 and int(player.y) >> 7 == int(y) >> 7)):
		move_steps = 2
	if (last_dx * dx <= 0 or last_dy * dy <= 0) \
			and main.random.randi_range(0, 2) != 2:
		move_steps = 0

	last_dx = dx
	last_dy = dy

	bomb_delay -= 1
	if bomb_delay < 0:
		bomb_delay = BOMB_DELAY
		Bomb.new(x, y, false, 0.75 * vx, 0.75 * vy)


func render() -> void:
	main.draw_vehicle(main.gray_jeeps, x, y, display_angle)
