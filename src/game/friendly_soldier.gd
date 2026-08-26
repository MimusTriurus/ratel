# Port of jackal.FriendlySoldier.
#
# Covers every rescued prisoner: the weapon carrier that walks out of a hut,
# the pairs that emerge from a POW house, the ones scattered when the player
# dies, and the ones walking to the rescue helicopter.
class_name FriendlySoldier
extends Enemy

const WALK_SPEED := 1.0
const MIN_WANDER_TIME := 1 * 91
const MAX_WANDER_TIME := 4 * 91
const MAX_WALK_STEPS := 5
const LEG_FRAMES := 26
const LEG_AMPLITUDE := 2.0
const WAVING_DELAY := 2 * 91

const STATE_ENTRY_DOWN := 0
const STATE_ENTRY_LEFT := 1
const STATE_ENTRY_RIGHT := 2
const STATE_WANDERING := 3
const STATE_WAVING := 4
const STATE_WALKING_TO_HELICOPTER := 5

const ORIENTATION_DOWN := 0
const ORIENTATION_RIGHT := 2
const ORIENTATION_UP := 4
const ORIENTATION_LEFT := 6
const ORIENTATION_WAVING_LEFT := 8
const ORIENTATION_WAVING_RIGHT := 10

static var WOBBLES: PackedFloat32Array = PackedFloat32Array()

# Live prisoner count; the rescue helicopter waits for it to reach zero.
static var count: int = 0

var type: int
var state: int
var solids: Array[Enemy]
var player: Player
var vx: float
var vy: float
var direction_x: float
var direction_y: float
var wandering: int
var orientation: int
var leg_index: int
var leg_frames: int
var color_changing: bool
var color_index: int
var wobble_x: float
var wobble_y: float
var entry: int
var wobble_scale_x: float
var wobble_scale_y: float
var entering: bool
var waving: int
var house_count: int
var brother: FriendlySoldier
var left: bool
var helicopter = null


static func _static_init() -> void:
	WOBBLES.resize(LEG_FRAMES)
	for i in range(LEG_FRAMES - 1, -1, -1):
		WOBBLES[i] = -LEG_AMPLITUDE * sin(2.0 * PI * i / float(LEG_FRAMES))


static func reset_count() -> void:
	count = 0


# house_count < 0 selects the plain "wanderer" constructor; helicopter set
# selects the walk-to-the-helicopter one.
func _init(p_x: float, p_y: float, p_type: int, p_house_count: int = -1,
		p_shack: bool = false, p_helicopter = null,
		p_color_changing: bool = false) -> void:
	super()
	x = p_x
	y = p_y
	type = p_type

	if p_helicopter != null:
		state = STATE_WALKING_TO_HELICOPTER
		helicopter = p_helicopter
		color_changing = p_color_changing
		if p_x > p_helicopter.x:
			orientation = ORIENTATION_LEFT
			direction_x = -1
			direction_y = 0
			vx = -WALK_SPEED
			vy = 0
		else:
			orientation = ORIENTATION_RIGHT
			direction_x = 1
			direction_y = 0
			vx = WALK_SPEED
			vy = 0
		wobble_scale_x = 0
		wobble_scale_y = 1
		return

	if p_house_count < 0:
		if p_type == FriendlySoldierType.WEAPON_CARRIER_WANDERER:
			color_changing = true
		_start_wandering()
		return

	house_count = p_house_count
	left = p_type == FriendlySoldierType.HOUSE_LEFT_WALKING \
		or p_type == FriendlySoldierType.HOUSE_LEFT_WAVING

	match p_type:
		FriendlySoldierType.WEAPON_CARRIER:
			state = STATE_ENTRY_DOWN
			entering = true
			color_changing = true
			orientation = ORIENTATION_DOWN
			entry = 68 if p_shack else 100
			wobble_scale_x = 1
			wobble_scale_y = 0
		FriendlySoldierType.WANDERER:
			state = STATE_WANDERING
		FriendlySoldierType.WEAPON_CARRIER_WANDERER:
			state = STATE_WANDERING
			color_changing = true
		FriendlySoldierType.HOUSE_LEFT_WALKING:
			state = STATE_ENTRY_LEFT
			entering = true
			orientation = ORIENTATION_LEFT
			wobble_scale_x = 0
			wobble_scale_y = 1
			entry = 141
			_spawn_brother()
		FriendlySoldierType.HOUSE_RIGHT_WALKING:
			state = STATE_ENTRY_RIGHT
			entering = true
			orientation = ORIENTATION_RIGHT
			wobble_scale_x = 0
			wobble_scale_y = 1
			entry = 141
			_spawn_brother()
		FriendlySoldierType.HOUSE_LEFT_WAVING:
			state = STATE_WAVING
			orientation = ORIENTATION_WAVING_LEFT
			wobble_scale_x = 0
			wobble_scale_y = 1
		FriendlySoldierType.HOUSE_RIGHT_WAVING:
			state = STATE_WAVING
			orientation = ORIENTATION_WAVING_RIGHT
			wobble_scale_x = 0
			wobble_scale_y = 1


static func new_walking(p_x: float, p_y: float, p_type: int, p_house_count: int,
		p_shack: bool) -> FriendlySoldier:
	return FriendlySoldier.new(p_x, p_y, p_type, p_house_count, p_shack)


static func to_helicopter(p_x: float, p_y: float, p_helicopter,
		p_color_changing: bool) -> FriendlySoldier:
	return FriendlySoldier.new(p_x, p_y,
		FriendlySoldierType.WALKING_TO_HELICOPTER, -1, false, p_helicopter,
		p_color_changing)


func init() -> void:
	super.init()

	count += 1

	solids = game_mode.solids
	player = game_mode.player

	layer = 2
	bullet_hits = 1

	# A zero-width hit box: the player has to drive over the soldier's centre.
	hit_x1 = 0
	hit_y1 = -40
	hit_x2 = 0
	hit_y2 = -20

	mine = true
	mine_x1 = 0
	mine_y1 = -40
	mine_x2 = 0
	mine_y2 = -20

	solid = true
	solid_x1 = -16
	solid_y1 = -60
	solid_x2 = 16
	solid_y2 = 6


# The prisoners come out of a house one at a time; each waves until the one
# ahead of it is collected.
func _spawn_brother() -> void:
	if house_count > 0:
		brother = FriendlySoldier.new(x, y,
			FriendlySoldierType.HOUSE_LEFT_WAVING if left
				else FriendlySoldierType.HOUSE_RIGHT_WAVING,
			house_count - 1, false)


func promote() -> void:
	if left:
		type = FriendlySoldierType.HOUSE_LEFT_WALKING
		state = STATE_ENTRY_LEFT
		orientation = ORIENTATION_LEFT
	else:
		type = FriendlySoldierType.HOUSE_RIGHT_WALKING
		state = STATE_ENTRY_RIGHT
		orientation = ORIENTATION_RIGHT
	entering = true
	entry = 141
	_spawn_brother()


func _start_wandering() -> void:
	state = STATE_WANDERING
	for i in 16:
		var angle := 6.283 * main.random.randf()
		direction_x = cos(angle)
		direction_y = sin(angle)
		if game_mode.is_driveable(x + direction_x * 32, y + direction_y * 32):
			break
	vx = direction_x * WALK_SPEED
	vy = direction_y * WALK_SPEED
	wandering = MIN_WANDER_TIME \
		+ main.random.randi_range(0, MAX_WANDER_TIME - MIN_WANDER_TIME - 1)
	_compute_orientation()


func _start_waving(randomize_side: bool, p_left: bool) -> void:
	state = STATE_WAVING
	wobble_x = 0
	wobble_y = 0
	if randomize_side:
		orientation = ORIENTATION_WAVING_LEFT if main.random.randi_range(0, 1) == 0 \
			else ORIENTATION_WAVING_RIGHT
	else:
		orientation = ORIENTATION_WAVING_LEFT if p_left else ORIENTATION_WAVING_RIGHT
	if orientation == ORIENTATION_WAVING_LEFT:
		wobble_x = -8
	waving = WAVING_DELAY


func _wave() -> void:
	if leg_frames == 0:
		leg_frames = LEG_FRAMES - 1
		leg_index = 1
	elif leg_frames == 13:
		leg_index = 0
	leg_frames -= 1

	if type == FriendlySoldierType.WEAPON_CARRIER \
			or type == FriendlySoldierType.WANDERER \
			or type == FriendlySoldierType.WEAPON_CARRIER_WANDERER:
		waving -= 1
		if waving <= 0:
			_start_wandering()


func _compute_orientation() -> void:
	wobble_scale_x = absf(direction_y)
	wobble_scale_y = absf(direction_x)

	if wobble_scale_y > wobble_scale_x:
		orientation = ORIENTATION_RIGHT if direction_x > 0 else ORIENTATION_LEFT
	else:
		orientation = ORIENTATION_DOWN if direction_y > 0 else ORIENTATION_UP


func _walk_at_right_angle_to_barrier() -> void:
	var direction := game_mode.suggest_direction_bounce(direction_x, direction_y)
	direction_x = direction[0]
	direction_y = direction[1]
	vx = WALK_SPEED * direction[0]
	vy = WALK_SPEED * direction[1]
	_compute_orientation()


func _update_legs() -> void:
	if leg_frames == 0:
		leg_frames = LEG_FRAMES - 1
		leg_index = 1
	elif leg_frames == 13:
		leg_index = 0
	wobble_x = wobble_scale_x * WOBBLES[leg_frames]
	wobble_y = wobble_scale_y * WOBBLES[leg_frames]
	leg_frames -= 1


func _enter_left() -> void:
	entry -= 1
	if entry <= 0:
		_start_waving(false, true)
		return
	if entry < 120:
		x -= 1.0
		_update_legs()


func _enter_right() -> void:
	entry -= 1
	if entry <= 0:
		_start_waving(false, false)
		return
	if entry < 120:
		x += 1.0
		_update_legs()


func _enter_down() -> void:
	entry -= 1
	if entry <= 0:
		_start_waving(true, false)
		return
	if entry < 79:
		y += 2.0
		_update_legs()


func _walk_to_helicopter() -> void:
	x += vx
	_update_legs()

	if (vx < 0 and x <= helicopter.x) or (vx > 0 and x >= helicopter.x):
		do_remove()
		helicopter.friendly_soldier_picked_up()


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


func _wander() -> void:
	var next_x := x + vx
	var next_y := y + vy
	var walkable := true
	if game_mode.is_driveable_box(next_x - 16, next_y - 6, next_x + 16, next_y + 6):
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
		_update_legs()
	else:
		_walk_at_right_angle_to_barrier()

	wandering -= 1
	if wandering <= 0:
		_start_waving(true, false)


func bump(x1: float, y1: float, x2: float, y2: float, _invincible: bool) -> bool:
	if type != FriendlySoldierType.WALKING_TO_HELICOPTER and is_mine_rect(x1, y1, x2, y2):
		do_remove()
		if type == FriendlySoldierType.WEAPON_CARRIER \
				or type == FriendlySoldierType.WEAPON_CARRIER_WANDERER:
			game_mode.player.pick_up_flashing_soldier()
		else:
			game_mode.player.collect_pow()
		if brother != null:
			brother.promote()
	return false


func attack(_x1: float, _y1: float, _x2: float, _y2: float,
		_attack_source: int) -> bool:
	return false


func bullet_attack(_x1: float, _y1: float, _x2: float, _y2: float) -> bool:
	return false


func do_remove() -> void:
	if not remove:
		remove = true
		count -= 1


func flatten() -> void:
	pass


func explode() -> void:
	pass


func update() -> void:
	if game_mode.ending_camera_pan or not game_mode.playing:
		return

	_convey()

	match state:
		STATE_ENTRY_DOWN:
			_enter_down()
		STATE_ENTRY_RIGHT:
			_enter_right()
		STATE_ENTRY_LEFT:
			_enter_left()
		STATE_WAVING:
			_wave()
		STATE_WANDERING:
			_wander()
		STATE_WALKING_TO_HELICOPTER:
			_walk_to_helicopter()


func render() -> void:
	if color_changing:
		color_index = (color_index + 1) & 3
	var y_offset := 60.0 if (orientation == ORIENTATION_LEFT
		or orientation == ORIENTATION_RIGHT) else 56.0
	main.draw(main.friendly_soldiers[color_index][orientation + leg_index],
		x + wobble_x - 16, y + wobble_y - y_offset)
