# Port of jackal.FriendlyHelicopter.
#
# The rescue helicopter. It sits on the pad taking prisoners aboard, then revs
# up, lifts off, accelerates, banks through a precomputed turn and flies away.
# Height is faked with a scale factor and a separate shadow.
class_name FriendlyHelicopter
extends GameElement

const DROP_OFF_DELAY := 91
const FLIGHT_SPEED := 6.0
const ACCELERATION_TIME := 45
const ACCELERATION := FLIGHT_SPEED / ACCELERATION_TIME
const TAKE_OFF_DELAY := 91 * 2
const TURN_RADIUS1 := 192.0
const TURN_RADIUS2 := 192.0
const INITIAL_PLANE_SPAWN_DELAY := 3 * 91
const PLANE_SPAWN_DELAY := 10 * 91

const STATE_PICK_UP := 0
const STATE_REVVING_UP := 1
const STATE_LIFTING_OFF := 2
const STATE_ACCELERATING := 3
const STATE_TURNING := 4
const STATE_FLYING_AWAY := 5
const STATE_FLYING_TOWARD := 6

const Y0 := 128.0
const Y1 := 116.0
const K1 := Y1 / Y0
const Z0 := K1 / (K1 - 1.0)

const SHADOW_Y0 := 36.0
const SHADOW_K := (Y1 - SHADOW_Y0) / SHADOW_Y0

static var HEIGHTS: PackedFloat32Array = PackedFloat32Array()
static var TURNS: Array = []          # each entry is [x, y, angle]
static var TURNS_LENGTH: int = 0

var angle: float
var rotor_angle: float
var rotor_speed: float
var slow_rotor: bool
var z: float
var left_stop: bool
var state: int
var walking_soldiers: int
var player: Player
var drop_off_delay: int = 45
var preparing_to_take_off: int = TAKE_OFF_DELAY
var revving_up: int
var lifting_off: int
var accelerating: int
var turning: int
var plane_spawn_delay: int = INITIAL_PLANE_SPAWN_DELAY
var turn_x: float
var turn_y: float
var created_plane: bool


static func _static_init() -> void:
	HEIGHTS.resize(91)
	for i in 91:
		HEIGHTS[i] = 0.5 * (1.0 + cos(PI * i / 91.0))

	# A 45 degree bank followed by a 225 degree sweep, baked into a path table.
	var turn1_steps := int(ceil(2 * PI * (45.0 / 360.0) * TURN_RADIUS1 / FLIGHT_SPEED))
	var turn2_steps := int(ceil(2 * PI * (225.0 / 360.0) * TURN_RADIUS2 / FLIGHT_SPEED))
	TURNS_LENGTH = turn1_steps + turn2_steps
	TURNS = []
	TURNS.resize(TURNS_LENGTH)

	for i in turn1_steps:
		var percent := i / float(turn1_steps)
		var helicopter_angle := 45.0 * percent
		var a := percent * (PI / 4.0)
		TURNS[i] = [
			TURN_RADIUS1 - TURN_RADIUS1 * cos(a),
			TURN_RADIUS1 * -sin(a),
			helicopter_angle,
		]

	var distance := TURN_RADIUS1 + TURN_RADIUS2
	var k := 1.0 / sqrt(2.0)
	var center_x := TURN_RADIUS1 - k * distance
	var center_y := -k * distance

	for i in turn2_steps:
		var percent := i / float(turn2_steps)
		var helicopter_angle := 45.0 - 225.0 * percent
		var a := PI / 4.0 - PI * 1.25 * percent
		TURNS[turn1_steps + i] = [
			center_x + TURN_RADIUS2 * cos(a),
			center_y + TURN_RADIUS2 * sin(a),
			helicopter_angle,
		]


func _init(p_x: float, p_y: float, landing: bool, p_left_stop: bool) -> void:
	super()
	x = p_x
	y = p_y
	player = game_mode.player
	left_stop = p_left_stop

	if landing:
		slow_rotor = false
		z = 0
		state = STATE_FLYING_TOWARD
		rotor_speed = 30
		change_layer(7)
	else:
		slow_rotor = true
		z = 1
		state = STATE_PICK_UP
		rotor_speed = 15


func init() -> void:
	layer = 3


func do_remove() -> void:
	remove = true
	main.stop_sound(main.helicopter_sound2)


func update() -> void:
	rotor_angle -= rotor_speed
	if rotor_angle <= -360:
		rotor_angle += 360

	if state >= STATE_ACCELERATING:
		main.play_sound_if_not_playing(main.helicopter_sound2)

	match state:
		STATE_PICK_UP:
			_update_pick_up()
		STATE_REVVING_UP:
			rotor_speed = 15.0 + 15.0 * revving_up / 90.0
			if revving_up >= 45:
				slow_rotor = false
				change_layer(7)
			revving_up += 1
			if revving_up == 91:
				rotor_speed = 30.0
				state = STATE_LIFTING_OFF
		STATE_LIFTING_OFF:
			z = HEIGHTS[lifting_off] if lifting_off < 91 else 0.0
			lifting_off += 1
			if lifting_off == 114:
				state = STATE_ACCELERATING
		STATE_ACCELERATING:
			y -= accelerating * ACCELERATION
			accelerating += 1
			if accelerating == ACCELERATION_TIME:
				state = STATE_TURNING
				turn_x = x
				turn_y = y
		STATE_TURNING:
			var t: Array = TURNS[turning]
			x = turn_x + t[0]
			y = turn_y + t[1]
			angle = t[2]
			turning += 1
			if turning == TURNS_LENGTH:
				state = STATE_FLYING_AWAY
				angle = -180
		STATE_FLYING_AWAY:
			y += FLIGHT_SPEED
			if y > game_mode.camera_y + Main.SCREEN_HEIGHT + 128:
				do_remove()
		STATE_FLYING_TOWARD:
			y -= FLIGHT_SPEED
			if y < game_mode.camera_y - 128:
				do_remove()


func _update_pick_up() -> void:
	if player.pows > 0:
		var dx := player.x - x

		# While the player is loitering by the pad, the stage sends air cover.
		if absf(player.y - y) <= 128:
			plane_spawn_delay -= 1
			if plane_spawn_delay == 0:
				plane_spawn_delay = PLANE_SPAWN_DELAY
				if game_mode.stage_index == 5:
					EnemyHelicopter.new(true)
				elif game_mode.stage_index == 4:
					Airplane.from_landing_port(left_stop)
				elif game_mode.stage_index == 1:
					if not created_plane:
						created_plane = true
						Airplane.from_landing_port(left_stop)

		if player.y > y - 66 and player.y < y + 49 \
				and ((not left_stop and dx > 0 and dx < 320)
					or (left_stop and dx < 0 and dx > -320)):
			if drop_off_delay > 0:
				drop_off_delay -= 1
			else:
				drop_off_delay = DROP_OFF_DELAY
				FriendlySoldier.to_helicopter(player.x, player.y + 28, self,
					player.pows == 1)
				player.drop_off_pow()
				walking_soldiers += 1

	if walking_soldiers == 0 and player.y < y + 80 \
			and ((FriendlySoldier.count == 0 and player.pows == 0)
				or player.y < y - 512):
		if preparing_to_take_off > 0:
			preparing_to_take_off -= 1
		else:
			state = STATE_REVVING_UP
	else:
		preparing_to_take_off = TAKE_OFF_DELAY


func friendly_soldier_picked_up() -> void:
	walking_soldiers -= 1
	if not main.friendly_soldier_picked_up():
		main.play_sound(main.helicopter_pickup_sound)


func render() -> void:
	var blade: Spr
	var offset := 0.0
	if slow_rotor:
		blade = main.friendly_helicopters[2]
		offset = -9
	else:
		blade = main.friendly_helicopters[3]
		offset = -14

	if z < 1:
		var s0 := 1 + SHADOW_K * z
		var s1 := 1 - z
		main.draw_rotated_offset_scaled(main.friendly_helicopters[1],
			x + 32 * s1, y + 37 * s1, -10, -18, angle, s0, 1 - z)

	var scale := Z0 / (Z0 - z)
	main.draw_rotated_offset_scaled(main.friendly_helicopters[0], x, y,
		-36, -60, angle, scale)
	for i in 4:
		main.draw_rotated_offset_scaled(blade, x, y, 0, offset,
			rotor_angle + 90 * i, scale)
