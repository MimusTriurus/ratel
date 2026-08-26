# Port of jackal.GrayTank.
#
# Same driving logic as BrownTank but tougher, faster and with a longer barrel;
# it can also emerge from a shack or from the boss garage, during which it is
# invulnerable and ignores terrain.
class_name GrayTank
extends Enemy

const SPEED := 1.5
const SENSOR_RADIUS := 56
const ANGLE_STEPS := 24
const ANGLE_VELOCITY := 45.0 / ANGLE_STEPS
const SHOOT_DELAY := 45
const SHOOT_LONG_DELAY := 91
const SHOOT_COUNT := 3
const BULLET_TRAVEL_TIME := 2 * 91
const BULLET_SPEED := 1.4

const MAX_MOVE_SQUARES := 8

const DIMENSION_1 := 52.0
const DIMENSION_2 := 40.0

# Muzzle offset per facing, indexed by target_angle / 45.
const MUZZLE: Array[Vector2] = [
	Vector2(48, -6),
	Vector2(37, 31),
	Vector2(0, 52),
	Vector2(-37, 31),
	Vector2(-48, -6),
	Vector2(-31, -37),
	Vector2(0, -52),
	Vector2(31, -37),
]

var shoot_delay: int = SHOOT_DELAY
var shoot_count: int = SHOOT_COUNT
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
var first_move: int
var shack: bool
var shack_x: float
var shack_y: float
var garage: bool
var boss_garage_manager = null


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y
	first_move = 2 * 91


static func from_shack(p_x: float, p_y: float) -> GrayTank:
	var t := GrayTank.new(p_x, p_y)
	t.shack = true
	t.shack_x = p_x - 62
	t.shack_y = p_y - 80
	t.first_move = 105
	return t


static func from_garage(p_x: float, p_y: float, p_first_move: int) -> GrayTank:
	var t := GrayTank.new(p_x, p_y)
	t.first_move = p_first_move
	t.garage = true
	return t


static func from_garage_tracked(p_x: float, p_y: float, p_first_move: int,
		p_manager) -> GrayTank:
	var t := GrayTank.from_garage(p_x, p_y, p_first_move)
	t.boss_garage_manager = p_manager
	if p_manager != null:
		p_manager.tank_created()
		t.points = 0
	return t


func init() -> void:
	super.init()

	solids = game_mode.solids
	player = game_mode.player

	layer = 3

	bullet_hits = 5

	hit_x1 = -50
	hit_y1 = -50
	hit_x2 = 50
	hit_y2 = 50

	mine = true
	mine_x1 = -35
	mine_y1 = -35
	mine_x2 = 35
	mine_y2 = 35

	solid = true
	solid_x1 = -52
	solid_y1 = -52
	solid_x2 = 52
	solid_y2 = 52

	points = 800


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


func _compute_move_steps() -> void:
	var v := direction_x if direction_x != 0 else direction_y
	if v == 0:
		return

	var d := 32 - fmod(v, 32.0) if v > 0 else fmod(v, 32.0)
	d += 32 * (1 + main.random.randi_range(0, MAX_MOVE_SQUARES - 1))

	if first_move > 0:
		move_steps = 16
	else:
		move_steps = roundi(d / SPEED)


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
		shoot_count = SHOOT_COUNT
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

	if first_move > 0:
		first_move -= 1
		if first_move == 0:
			garage = false
			shack = false

	move_steps -= 1
	if move_steps <= 0:
		var dx := 0
		var dy := 0
		if main.random.randi_range(0, 4) == 4:
			dx = main.random.randi_range(0, 511) - 256
			dy = main.random.randi_range(0, 511) - 256
		var v: PackedFloat32Array
		if first_move > 0:
			v = main.create_unit_vector(90)
			v[2] = 90
		elif handling_loop > 0:
			v = game_mode.suggest_direction(x, y, loop_target_x + dx,
				loop_target_y + dy, false)
		else:
			v = game_mode.suggest_direction(x, y, player.x + dx, player.y + dy, false)
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

	if not (garage or shack):
		_test_corners(next_x, next_y)

	var driveable := true

	if game_mode.is_driveable(next_x + sensor_x, next_y + sensor_y) or garage or shack:
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
	elif garage or shack:
		first_move += 1
	else:
		_drive_at_right_angle_to_barrier()

	var dx := player.x - x
	var dy := player.y - y

	if move_steps == 1 and ((vy != 0 and int(player.x) >> 7 == int(x) >> 7)
			or (vx != 0 and int(player.y) >> 7 == int(y) >> 7)):
		move_steps = 2
	if (last_dx * dx <= 0 or last_dy * dy <= 0) \
			and main.random.randi_range(0, 2) != 2 and first_move == 0:
		move_steps = 0

	last_dx = dx
	last_dy = dy

	shoot_delay -= 1
	if shoot_delay <= 0:
		shoot_count -= 1
		if shoot_count <= 0:
			shoot_count = SHOOT_COUNT
			shoot_delay = SHOOT_LONG_DELAY
		else:
			shoot_delay = SHOOT_DELAY
		var b := Vector2.ZERO
		var a := target_angle % 360
		if a % 45 == 0:
			b = MUZZLE[(a / 45) % 8]
		EnemyBullet.new(x + b.x, y + b.y,
			BULLET_SPEED * direction_x, BULLET_SPEED * direction_y,
			BULLET_TRAVEL_TIME)


# A tank still inside its shack cannot be hurt.
func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if shack and first_move > 40:
		return false
	return super.attack(x1, y1, x2, y2, attack_source)


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	if shack and first_move > 40:
		return false
	return super.bullet_attack(x1, y1, x2, y2)


func do_remove() -> void:
	super.do_remove()
	if boss_garage_manager != null:
		boss_garage_manager.tank_destroyed()


func render() -> void:
	main.draw_vehicle(main.gray_tanks, x, y, display_angle)
	if shack and first_move > 0:
		main.draw(main.tank_shack, shack_x, shack_y)
