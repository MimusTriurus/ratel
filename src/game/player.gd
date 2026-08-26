# Port of jackal.Player.
class_name Player
extends RefCounted

const SPEED := 2.5
const ANGLE_STEPS := 8
const ANGLE_VELOCITY := 45.0 / ANGLE_STEPS
const DIAGONAL_DELAY := 4
const GUN_ARMED_DELAY := 45
const RESPAWN_DELAY := 91 * 2
const INVINCIBLE_DELAY := 91 * 3

const SENSOR_X := 32
const SENSOR_Y := 16

static var SENSOR_D_X0: int
static var SENSOR_D_X1: int
static var SENSOR_D_X2: int
static var SENSOR_D_Y0: int
static var SENSOR_D_Y1: int
static var SENSOR_D_Y2: int

static var RUMBLE: PackedFloat32Array = PackedFloat32Array()
static var WAKE_ALPHAS: PackedFloat32Array = PackedFloat32Array()


static func _static_init() -> void:
	RUMBLE.resize(17)
	WAKE_ALPHAS.resize(17)
	var angle := 0.0
	for i in 17:
		WAKE_ALPHAS[i] = 0.5 + 0.5 * sin(angle)
		RUMBLE[i] = 1.6 * sin(angle)
		angle += 0.74

	# Diagonal collision sensors are the axis-aligned ones rotated 45 degrees.
	var p0 := Main.rotate_point(SENSOR_X + SPEED, 0, PI / 4.0)
	var p1 := Main.rotate_point(SENSOR_X + SPEED, SENSOR_Y, PI / 4.0)
	var p2 := Main.rotate_point(SENSOR_X + SPEED, -SENSOR_Y, PI / 4.0)

	SENSOR_D_X0 = int(p0.x)
	SENSOR_D_Y0 = int(p0.y)
	SENSOR_D_X1 = int(p1.x)
	SENSOR_D_Y1 = int(p1.y)
	SENSOR_D_X2 = int(p2.x)
	SENSOR_D_Y2 = int(p2.y)


var main: Main
var game_mode: GameMode
var input: HumanInput
var mines: Array[Enemy]

var x: float = 512
var y: float = 480
var angle: int = 270
var next_angle: int = 270
var display_angle: float = 270
var angle_velocity: float = 0
var angle_steps: int = 0
var diagonal_delay: int = 0
var target_angle: int = 0
var last_target_angle: int = 270
var fire_angle: int = 270
var rumble: int = 0
var invincible: int = 0
var invincible_color: int = 0
var weapon_armed: bool = true
var gun_armed: int = 0
var fire_released: bool
var shoot_released: bool
var long_range: bool
var respawning: int
var pows: int
var releaseable_pows: int
var in_swamp: bool


func _init() -> void:
	main = Main.main
	game_mode = Main.game_mode
	input = main.input
	mines = game_mode.mines


func set_weapon_armed(p_weapon_armed: bool) -> void:
	weapon_armed = p_weapon_armed


func pick_up_flashing_soldier() -> void:
	pows += 1
	main.upgrade_weapon(true)


func collect_pow() -> void:
	pows += 1
	releaseable_pows += 1
	main.play_sound(main.pickup_sound)


func drop_off_pow() -> void:
	pows -= 1
	if pows < releaseable_pows:
		releaseable_pows = pows


func explode() -> void:
	if game_mode.stage_completed:
		return

	main.play_sound(main.player_explode_sound)
	if main.extra_lives == 0:
		main.stop_song()
	Explosion.new(x, y, true)

	# Carried POWs scatter, and occasionally one of them carries the weapon.
	if releaseable_pows > 1:
		var weapon_carrier: bool = main.has_missiles and main.random.randi_range(0, 4) == 3
		if weapon_carrier:
			releaseable_pows += 1
		var release := releaseable_pows - 2
		if release > 3:
			release = 3
		for i in range(release, -1, -1):
			FriendlySoldier.new(x, y,
				FriendlySoldierType.WEAPON_CARRIER_WANDERER if (weapon_carrier and i == 0)
				else FriendlySoldierType.WANDERER)

	pows = 0
	releaseable_pows = 0
	main.missile_power = 0
	main.has_missiles = false
	respawning = RESPAWN_DELAY


func attack_rect(x1: float, y1: float, x2: float, y2: float) -> bool:
	if respawning == 0 and invincible == 0 \
			and x1 <= x + 32 and x2 >= x - 32 and y1 <= y + 32 and y2 >= y - 32:
		explode()
		return true
	return false


func attack(px: float, py: float) -> bool:
	if respawning == 0 and invincible == 0 \
			and px >= x - 32 and px <= x + 32 and py >= y - 32 and py <= y + 32:
		explode()
		return true
	return false


func collect_flashing_star() -> void:
	main.play_sound(main.weapon_upgrade_sound)
	main.has_missiles = true
	main.missile_power = 2


func get_speed() -> float:
	return 0.5 * SPEED if in_swamp else SPEED


func make_invincible() -> void:
	invincible = INVINCIBLE_DELAY


func update() -> void:
	var tile_type := game_mode.get_tile_type(x, y)
	in_swamp = tile_type == GameMode.TYPE_SWAMP
	var speed := get_speed()

	if respawning > 0:
		respawning -= 1
		if respawning == 0:
			if main.extra_lives > 0:
				main.lose_life()
				invincible = INVINCIBLE_DELAY
			elif not game_mode.stage_completed:
				main.konami_code.enabled = false
				main.request_mode(Modes.CONTINUE)
		else:
			return

	if tile_type == GameMode.TYPE_CONVEYOR:
		var Y := y + SENSOR_X + SPEED
		if game_mode.is_driveable(x, Y) \
				and game_mode.is_driveable(x - SENSOR_Y, Y) \
				and game_mode.is_driveable(x + SENSOR_Y, Y):
			y += game_mode.conveyor_delta

	target_angle = -1
	if input.is_down() and input.is_right():
		fire_angle = 45
		target_angle = 45
		last_target_angle = target_angle
		diagonal_delay = DIAGONAL_DELAY
		if game_mode.is_driveable(x + SENSOR_D_X0, y + SENSOR_D_Y0) \
				and game_mode.is_driveable(x + SENSOR_D_X1, y + SENSOR_D_Y1) \
				and game_mode.is_driveable(x + SENSOR_D_X2, y + SENSOR_D_Y2):
			x += speed
			y += speed
	elif input.is_down() and input.is_left():
		fire_angle = 135
		target_angle = 135
		last_target_angle = target_angle
		diagonal_delay = DIAGONAL_DELAY
		if game_mode.is_driveable(x - SENSOR_D_X0, y + SENSOR_D_Y0) \
				and game_mode.is_driveable(x - SENSOR_D_X1, y + SENSOR_D_Y1) \
				and game_mode.is_driveable(x - SENSOR_D_X2, y + SENSOR_D_Y2):
			x -= speed
			y += speed
	elif input.is_up() and input.is_left():
		fire_angle = 225
		target_angle = 225
		last_target_angle = target_angle
		diagonal_delay = DIAGONAL_DELAY
		if game_mode.is_driveable(x - SENSOR_D_X0, y - SENSOR_D_Y0) \
				and game_mode.is_driveable(x - SENSOR_D_X1, y - SENSOR_D_Y1) \
				and game_mode.is_driveable(x - SENSOR_D_X2, y - SENSOR_D_Y2):
			x -= speed
			y -= speed
	elif input.is_up() and input.is_right():
		fire_angle = 315
		target_angle = 315
		last_target_angle = target_angle
		diagonal_delay = DIAGONAL_DELAY
		if game_mode.is_driveable(x + SENSOR_D_X0, y - SENSOR_D_Y0) \
				and game_mode.is_driveable(x + SENSOR_D_X1, y - SENSOR_D_Y1) \
				and game_mode.is_driveable(x + SENSOR_D_X2, y - SENSOR_D_Y2):
			x += speed
			y -= speed
	elif input.is_right():
		fire_angle = 0
		# Releasing one half of a diagonal keeps the diagonal briefly, so that
		# rolling off the stick does not snap the jeep to an axis.
		if (last_target_angle == 45 or last_target_angle == 315) and diagonal_delay > 0:
			diagonal_delay -= 1
		else:
			target_angle = 0
			last_target_angle = target_angle
			diagonal_delay = 0
			var X := x + SENSOR_X + SPEED
			if game_mode.is_driveable(X, y) \
					and game_mode.is_driveable(X, y - SENSOR_Y) \
					and game_mode.is_driveable(X, y + SENSOR_Y):
				x += speed
	elif input.is_down():
		fire_angle = 90
		if (last_target_angle == 45 or last_target_angle == 135) and diagonal_delay > 0:
			diagonal_delay -= 1
		else:
			target_angle = 90
			last_target_angle = target_angle
			diagonal_delay = 0
			var Y := y + SENSOR_X + SPEED
			if game_mode.is_driveable(x, Y) \
					and game_mode.is_driveable(x - SENSOR_Y, Y) \
					and game_mode.is_driveable(x + SENSOR_Y, Y):
				y += speed
	elif input.is_left():
		fire_angle = 180
		if (last_target_angle == 135 or last_target_angle == 225) and diagonal_delay > 0:
			diagonal_delay -= 1
		else:
			target_angle = 180
			last_target_angle = target_angle
			diagonal_delay = 0
			var X := x - SENSOR_X - SPEED
			if game_mode.is_driveable(X, y) \
					and game_mode.is_driveable(X, y - SENSOR_Y) \
					and game_mode.is_driveable(X, y + SENSOR_Y):
				x -= speed
	elif input.is_up():
		fire_angle = 270
		if (last_target_angle == 225 or last_target_angle == 315) and diagonal_delay > 0:
			diagonal_delay -= 1
		else:
			target_angle = 270
			last_target_angle = target_angle
			diagonal_delay = 0
			var Y := y - SENSOR_X - SPEED
			if game_mode.is_driveable(x, Y) \
					and game_mode.is_driveable(x - SENSOR_Y, Y) \
					and game_mode.is_driveable(x + SENSOR_Y, Y):
				y -= speed
	else:
		diagonal_delay = 0

	if y > game_mode.max_camera_y + 928:
		y = game_mode.max_camera_y + 928

	if angle_steps > 0:
		angle_steps -= 1
		if angle_steps == 0:
			angle = next_angle
			display_angle = next_angle
		else:
			display_angle += angle_velocity

	# Turning always takes the short way round, 45 degrees at a time.
	if angle_steps == 0 and target_angle != -1 and target_angle != angle:
		angle_steps = ANGLE_STEPS
		if target_angle == 0:
			if angle >= 180:
				next_angle = angle + 45
				if next_angle == 360:
					next_angle = 0
				angle_velocity = ANGLE_VELOCITY
			else:
				next_angle = angle - 45
				angle_velocity = -ANGLE_VELOCITY
		elif target_angle == 180:
			if angle > 180:
				next_angle = angle - 45
				angle_velocity = -ANGLE_VELOCITY
			elif angle == 0:
				next_angle = 315
				angle_velocity = -ANGLE_VELOCITY
			else:
				next_angle = angle + 45
				angle_velocity = ANGLE_VELOCITY
		elif target_angle > 180:
			if angle < target_angle and angle >= target_angle - 180:
				next_angle = angle + 45
				angle_velocity = ANGLE_VELOCITY
			else:
				next_angle = angle - 45
				angle_velocity = -ANGLE_VELOCITY
		else:
			if angle > target_angle and angle <= target_angle + 180:
				next_angle = angle - 45
				angle_velocity = -ANGLE_VELOCITY
			else:
				next_angle = angle + 45
				angle_velocity = ANGLE_VELOCITY
		if next_angle == -45:
			next_angle = 315
		elif next_angle == 360:
			next_angle = 0

	if invincible > 0:
		invincible -= 1

	if input.is_fire():
		if fire_released and weapon_armed:
			fire_released = false
			weapon_armed = false
			if target_angle == -1 and angle_steps == 0:
				fire_angle = angle
			if main.has_missiles:
				PlayerMissile.new(x, y, fire_angle, main.missile_power)
			else:
				Grenade.new(x, y, fire_angle)
	else:
		fire_released = true

	if gun_armed > 0:
		gun_armed -= 1
	if input.is_shoot():
		if shoot_released or gun_armed == 0:
			PlayerBullet.new(x, y)
			gun_armed = GUN_ARMED_DELAY
		shoot_released = false
	else:
		shoot_released = true
		gun_armed = 0

	var is_invincible := invincible > 0
	var x_margin := 32.0
	var y_margin := 32.0
	if angle == 0 or angle == 180:
		x_margin = 48.0
	elif angle == 90 or angle == 270:
		y_margin = 46.0
	for i in range(mines.size() - 1, -1, -1):
		var m: Enemy = mines[i]
		if m.bump(x - x_margin, y - y_margin, x + x_margin, y + y_margin, is_invincible):
			if not is_invincible:
				explode()
				break


# The rumble and invincibility flash advance once per rendered frame, exactly
# as in the original's render().
func render() -> void:
	if respawning != 0:
		return

	if target_angle != -1 and not game_mode.boss_camera_pan 			and not game_mode.ending_camera_pan and game_mode.playing 			and not game_mode.paused:
		rumble += 1
		if rumble == 17:
			rumble = 0

	if invincible > 0:
		if not game_mode.paused:
			invincible_color += 1
			if invincible_color == 4:
				invincible_color = 0
	else:
		invincible_color = 0

	if in_swamp and target_angle != -1 and angle_steps == 0:
		var a: float = WAKE_ALPHAS[rumble]
		match next_angle:
			0, 360:
				main.draw(main.player_wakes[0], x - 37, y - 43, a)
			45:
				main.draw_rotated_alpha(main.player_wakes[4], x - 8, y - 2, 90, a)
			90:
				main.draw(main.player_wakes[3], x - 52, y - 31, a)
			135:
				main.draw_rotated_alpha(main.player_wakes[5], x + 8, y + 2, -90, a)
			180:
				main.draw(main.player_wakes[1], x - 27, y - 43, a)
			225:
				main.draw(main.player_wakes[5], x - 42, y - 36, a)
			270:
				main.draw(main.player_wakes[2], x - 52, y - 31, a)
			315:
				main.draw(main.player_wakes[4], x - 49, y - 36, a)

	main.draw_vehicle(main.players[invincible_color], x, y + RUMBLE[rumble], display_angle)
