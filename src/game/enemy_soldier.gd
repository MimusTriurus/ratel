# Port of jackal.EnemySoldier.
#
# A soldier alternates between seeking (walking towards the player along the
# stage flow field) and aiming (standing still, blinking, then firing).
class_name EnemySoldier
extends Enemy

const WALK_SPEED := 0.5
const MIN_WALK_TIME := 1 * 91
const MAX_WALK_TIME := 4 * 91
const MAX_WALK_STEPS := 5
const LEG_FRAMES := 26
const LEG_AMPLITUDE := 2.0
const AIM_FRAMES := 114
const AIM_BLINKING := 23
const AIM_RESHOOT := 11
const EXTRA_AIMING_TIME := 2 * 91
const BULLET_TRAVEL_TIME := 1 * 91
const TO_DEGREES := 180.0 / PI

const STATE_SEEKING := 0
const STATE_AIMING := 1

const ORIENTATION_DOWN := 0
const ORIENTATION_RIGHT := 2
const ORIENTATION_UP := 4
const ORIENTATION_LEFT := 6

static var WOBBLES: PackedFloat32Array = PackedFloat32Array()

var type: int
var state: int = STATE_SEEKING
var solids: Array[Enemy]
var player: Player
var target_vx: float
var target_vy: float
var direction_x: float
var direction_y: float
var walking: int
var aiming: int
var orientation: int
var leg_index: int
var leg_frames: int
var walk_steps: int
var blink: int
var wobble_x: float
var wobble_y: float
var wobble_scale_x: float
var wobble_scale_y: float
var shots: int
var total_shots: int
var in_swamp: bool
var boss_helicopter = null
var fire: bool


static func _static_init() -> void:
	WOBBLES.resize(LEG_FRAMES)
	for i in range(LEG_FRAMES - 1, -1, -1):
		WOBBLES[i] = -LEG_AMPLITUDE * sin(2.0 * PI * i / float(LEG_FRAMES))


func _init(p_x: float, p_y: float, p_type: int) -> void:
	super()
	x = p_x
	y = p_y
	type = p_type

	match p_type:
		EnemySoldierType.APPEARING:
			_run_upwards()
		EnemySoldierType.WALKER:
			_start_seeking()
		EnemySoldierType.STATIONARY:
			_start_aiming()
		EnemySoldierType.TROOPS_TRUCK:
			_run_left()
		EnemySoldierType.FIRE:
			# Behaves like STATIONARY but throws flame instead of bullets.
			_start_aiming()
			fire = true

	if fire:
		total_shots = 1
	else:
		match game_mode.stage_index:
			0, 1:
				total_shots = 1
			2, 3:
				total_shots = 2
			4, 5:
				total_shots = 3


func init() -> void:
	super.init()

	solids = game_mode.solids
	player = game_mode.player

	layer = 3
	bullet_hits = 1

	hit_x1 = -16
	hit_y1 = -54
	hit_x2 = 16
	hit_y2 = 6

	mine = true
	mine_x1 = -16
	mine_y1 = -54
	mine_x2 = 16
	mine_y2 = 6

	solid = true
	solid_x1 = -16
	solid_y1 = -54
	solid_x2 = 16
	solid_y2 = 6

	points = 100


func set_boss_helicopter(p_boss_helicopter) -> void:
	boss_helicopter = p_boss_helicopter
	points = 10


func _compute_orientation() -> void:
	wobble_scale_x = absf(direction_y)
	wobble_scale_y = absf(direction_x)

	if wobble_scale_y > wobble_scale_x:
		orientation = ORIENTATION_RIGHT if direction_x > 0 else ORIENTATION_LEFT
	else:
		orientation = ORIENTATION_DOWN if direction_y > 0 else ORIENTATION_UP


func get_walk_speed() -> float:
	return 0.5 * WALK_SPEED if in_swamp else WALK_SPEED


func _target_player() -> void:
	var direction := game_mode.suggest_direction(x, y, player.x, player.y, true)

	direction_x = direction[0]
	direction_y = direction[1]
	target_vx = get_walk_speed() * direction[0]
	target_vy = get_walk_speed() * direction[1]

	walking = main.random.randi_range(0, MAX_WALK_TIME - MIN_WALK_TIME - 1) \
		+ MIN_WALK_TIME

	_compute_orientation()


func _avoid_getting_too_close_to_player() -> void:
	var dx := player.x - x
	var dy := player.y - y
	var r2 := dx * dx + dy * dy
	if r2 < 16384 and dx * direction_x + dy * direction_y > 0:
		var v := main.unit_vector
		var ir := 1.0 / sqrt(r2)
		v[0] = ir * -dx
		v[1] = ir * -dy
		game_mode.rotate(v, main.random.randf() * 0.3927 - 0.1963)
		direction_x = v[0]
		direction_y = v[1]
		target_vx = get_walk_speed() * direction_x
		target_vy = get_walk_speed() * direction_y
		walking = main.random.randi_range(0, MAX_WALK_TIME - MIN_WALK_TIME - 1) \
			+ MIN_WALK_TIME
		_compute_orientation()


func _walk_at_right_angle_to_barrier() -> void:
	var direction := game_mode.suggest_direction_bounce(direction_x, direction_y)
	direction_x = direction[0]
	direction_y = direction[1]
	target_vx = get_walk_speed() * direction[0]
	target_vy = get_walk_speed() * direction[1]
	_compute_orientation()


func _aim() -> void:
	direction_x = player.x - x
	direction_y = player.y - (y - 30)
	_compute_orientation()

	# Too close to shoot: a walker breaks off, anyone else just waits.
	if aiming > AIM_BLINKING:
		var r2 := direction_x * direction_x + direction_y * direction_y
		if r2 <= 9216:
			if type == EnemySoldierType.WALKER:
				_start_seeking()
			return

	aiming -= 1
	if aiming <= 0:
		_shoot()
		shots += 1
		if shots == total_shots:
			shots = 0
			if type == EnemySoldierType.WALKER:
				_start_seeking()
			else:
				_start_aiming()
		else:
			aiming = AIM_RESHOOT


func _shoot() -> void:
	var imag := 1.0 / sqrt(direction_x * direction_x + direction_y * direction_y)
	if fire:
		Fire.new(x, y - 30, direction_x * imag, direction_y * imag,
			TO_DEGREES * atan2(direction_y, direction_x), self)
	else:
		EnemyBullet.new(x, y - 30, direction_x * imag, direction_y * imag,
			BULLET_TRAVEL_TIME, EnemyBullet.SPRITE_WHITE)


func _start_aiming() -> void:
	state = STATE_AIMING
	aiming = AIM_FRAMES
	if type != EnemySoldierType.WALKER:
		aiming += main.random.randi_range(0, EXTRA_AIMING_TIME - 1)
	_aim()


func _run_left() -> void:
	state = STATE_SEEKING
	type = EnemySoldierType.WALKER

	direction_x = -1
	direction_y = 0
	target_vx = -get_walk_speed()
	target_vy = 0

	walk_steps = MAX_WALK_STEPS
	walking = MAX_WALK_TIME

	_compute_orientation()


func _run_upwards() -> void:
	state = STATE_SEEKING
	type = EnemySoldierType.WALKER

	direction_x = 0
	direction_y = -1
	target_vx = 0
	target_vy = -get_walk_speed()

	walk_steps = MAX_WALK_STEPS
	walking = MAX_WALK_TIME

	_compute_orientation()


func _start_seeking() -> void:
	state = STATE_SEEKING
	walk_steps = 1 + main.random.randi_range(0, MAX_WALK_STEPS - 1)
	_target_player()


func _seek() -> void:
	walking -= 1
	if walking <= 0:
		walk_steps -= 1
		if walk_steps <= 0:
			var dx := player.x - x
			var dy := player.y - y
			if dx * dx + dy * dy > 9216:
				_start_aiming()
				return
			_target_player()
		else:
			_target_player()

	_avoid_getting_too_close_to_player()

	var next_x := x + target_vx
	var next_y := y + target_vy
	var walkable := true
	if game_mode.is_driveable_box(next_x - 16, next_y - 6, next_x + 16, next_y + 6):
		# Avoid bumping into other enemies, but never get stuck inside one.
		for i in range(solids.size() - 1, -1, -1):
			var s: Enemy = solids[i]
			if s != self and s.is_solid_rect(next_x + solid_x1, next_y + solid_y1,
					next_x + solid_x2, next_y + solid_y2) \
					and not s.is_solid_rect(x + solid_x1, y + solid_y1,
						x + solid_x2, y + solid_y2):
				walkable = false
				break
	else:
		walkable = false

	if walkable:
		x = next_x
		y = next_y

		if leg_frames == 0:
			leg_frames = LEG_FRAMES - 1
			leg_index = 1
		elif leg_frames == 13:
			leg_index = 0
		wobble_x = wobble_scale_x * WOBBLES[leg_frames]
		wobble_y = wobble_scale_y * WOBBLES[leg_frames]
		leg_frames -= 1
	else:
		_walk_at_right_angle_to_barrier()


func _convey() -> void:
	if not (game_mode.conveyor_delta > 0 and game_mode.is_conveyor(x, y)):
		return

	var next_y := y + game_mode.conveyor_delta
	var walkable := true
	if game_mode.is_driveable_box(x - 16, next_y - 6, x + 16, next_y + 6):
		for i in range(solids.size() - 1, -1, -1):
			var s: Enemy = solids[i]
			if s != self and s.is_solid_rect(x + solid_x1, next_y + solid_y1,
					x + solid_x2, next_y + solid_y2) \
					and not s.is_solid_rect(x + solid_x1, y + solid_y1,
						x + solid_x2, y + solid_y2):
				walkable = false
				break
	else:
		walkable = false

	if walkable:
		y = next_y


func _walk() -> void:
	_convey()
	match state:
		STATE_SEEKING:
			_seek()
		STATE_AIMING:
			_aim()


func flatten() -> void:
	do_remove()
	DeadEnemySoldier.new(x, y)


func explode() -> void:
	do_remove()
	DeadEnemySoldier.new(x, y)
	Explosion.new(x, y)


func bump(x1: float, y1: float, x2: float, y2: float, _invincible: bool) -> bool:
	if is_mine_rect(x1, y1, x2, y2):
		do_remove()
		DeadEnemySoldier.new(x, y)
	return false


func attack(x1: float, y1: float, x2: float, y2: float,
		_attack_source: int) -> bool:
	if hit_rect(x1, y1, x2, y2):
		do_remove()
		DeadEnemySoldier.new(x, y)
	return false


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	if hit_rect(x1, y1, x2, y2):
		do_remove()
		DeadEnemySoldier.new(x, y)
		return true
	return false


func do_remove() -> void:
	remove = true
	if boss_helicopter != null:
		boss_helicopter.soldier_killed()
	if play_sound_on_remove and not game_mode.is_outside_of_frame_rect(
			x + hit_x1, y + hit_y1, x + hit_x2, y + hit_y2):
		main.play_sound(main.soldier_killed_sound)


func update() -> void:
	in_swamp = game_mode.is_swamp(x, y)
	if type == EnemySoldierType.WALKER:
		_walk()
	else:
		_aim()


func render() -> void:
	blink -= 1
	if blink < 0:
		blink = 4
	var sheets: Array = main.swamp_soldiers if in_swamp else main.enemy_soldiers
	var blinking: bool = blink < 2 and state == STATE_AIMING and aiming <= AIM_BLINKING
	# The flame soldier uses the opposite palette while blinking.
	var sheet: int
	if fire:
		sheet = 0 if blinking else 1
	else:
		sheet = 1 if blinking else 0
	main.draw(sheets[sheet][orientation + leg_index],
		x + wobble_x - 16, y + wobble_y - 54)
