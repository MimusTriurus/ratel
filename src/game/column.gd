# Port of jackal.Column.
#
# A pillar that topples sideways when the player drives into its trap zone (or
# shoots it), rolls down the screen crushing everything in its path, and comes
# to rest as a destructible obstacle.
class_name Column
extends Enemy

const STATE_HIDDEN := 0
const STATE_TIPPING := 1
const STATE_ROLLING := 2
const STATE_STATIONARY := 3

const ROTATION_SPEED := 0.6

const TRAP_X1 := -3.0 * 32
const TRAP_Y1 := 8.0 * 32
const TRAP_X2 := 5.0 * 32
const TRAP_Y2 := 16.0 * 32

const GRAVITY := 0.1
const TIP_VX := 2.5
const TIP_ANGLE_INC := 2.0
const ROLL_VY := 6.0
const ROLL_DISTANCE := 10.0 * 32
const ROLL_STEPS := 91
const ROLL_ACCELERATION := 2.0 * (ROLL_DISTANCE - ROLL_VY * ROLL_STEPS) \
	/ float(ROLL_STEPS * ROLL_STEPS)

var rotation_offset: float = 27.933975
var left: bool
var state: int = STATE_HIDDEN
var player: Player
var group_index: int
var angle: float = -90
var vx: float
var vy: float
var angle_inc: float
var tip_steps: int = int(90.0 / TIP_ANGLE_INC)
var can_drop_left: bool
var can_drop_right: bool
var mines: Array[Enemy]


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y

	player = game_mode.player

	var X := int(p_x) >> 5
	var Y := int(p_y) >> 5

	group_index = game_mode.groups_map[Y][X]

	# A column can only fall towards a side with clear ground to land on.
	can_drop_left = not (game_mode.is_solid_tile(X - 3, Y + 3)
		or game_mode.is_solid_tile(X - 3, Y + 4)
		or game_mode.is_solid_tile(X - 3, Y + 14))
	can_drop_right = not (game_mode.is_solid_tile(X + 4, Y + 3)
		or game_mode.is_solid_tile(X + 4, Y + 4)
		or game_mode.is_solid_tile(X + 4, Y + 14))


func init() -> void:
	super.init()

	mines = game_mode.mines

	layer = 4

	hit_x1 = 0
	hit_y1 = 0
	hit_x2 = 64
	hit_y2 = 92

	solid = true
	solid_x1 = 0
	solid_y1 = 0
	solid_x2 = 64
	solid_y2 = 92

	# While hidden the "mine" box is the oversized trap zone, not the pillar.
	mine = true
	mine_x1 = TRAP_X1
	mine_y1 = TRAP_Y1
	mine_x2 = TRAP_X2
	mine_y2 = TRAP_Y2

	points = 500
	bullet_hits = 7


func _roll_over_enemies() -> void:
	for i in range(mines.size() - 1, -1, -1):
		var m: Enemy = mines[i]
		if m != self and m.is_mine_rect(x + mine_x1, y + mine_y1,
				x + mine_x2, y + mine_y2):
			m.flatten()


func flatten() -> void:
	if state == STATE_STATIONARY:
		explode()


func update() -> void:
	match state:
		STATE_TIPPING:
			vy += GRAVITY
			x += vx
			y += vy
			angle += angle_inc
			tip_steps -= 1
			if tip_steps == 0:
				_start_rolling()
		STATE_ROLLING:
			vy += ROLL_ACCELERATION
			if vy <= 0:
				_stop_rolling()
			y += vy
			rotation_offset += ROTATION_SPEED * vy
			if rotation_offset >= 56:
				rotation_offset -= 56
			_roll_over_enemies()


func _start_rolling() -> void:
	state = STATE_ROLLING
	vy = ROLL_VY

	hit_x1 = -46
	hit_y1 = -28
	hit_x2 = 46
	hit_y2 = 28

	mine_x1 = -38
	mine_y1 = -20
	mine_x2 = 38
	mine_y2 = 20

	solid_x1 = -46
	solid_y1 = -28
	solid_x2 = 46
	solid_y2 = 28


func _stop_rolling() -> void:
	state = STATE_STATIONARY
	change_layer(3)


# When triggered by driving into the trap rather than by a weapon, the column
# only falls if the player is heading across its path.
func _start_tipping(attacked: bool) -> void:
	if not attacked:
		var heading_sideways: bool = player.target_angle <= 90 or player.target_angle >= 270
		if can_drop_left and can_drop_right:
			if player.x < x + 32:
				if not heading_sideways:
					return
			elif heading_sideways:
				return
		elif can_drop_left:
			if player.x < x + 32 or heading_sideways:
				return
		else:
			if player.x > x + 32 or not heading_sideways:
				return

	state = STATE_TIPPING
	main.play_hit_explode_sound()
	Explosion.new(x + 32, y + 48)
	game_mode.trigger_group(group_index)

	x += 32
	y += 46

	if can_drop_left and can_drop_right:
		if main.random.randi_range(0, 6) == 3:
			left = main.random.randi_range(0, 1) == 0
		elif main.random.randi_range(0, 2) == 1:
			left = player.x < x
		else:
			left = player.x > x
	else:
		left = can_drop_left

	if left:
		vx = -TIP_VX
		vy = 0
		angle_inc = -TIP_ANGLE_INC
	else:
		vx = TIP_VX
		vy = 0
		angle_inc = TIP_ANGLE_INC

	hit_x1 = -28
	hit_y1 = -28
	hit_x2 = 28
	hit_y2 = 28

	mine_x1 = -20
	mine_y1 = -20
	mine_x2 = 20
	mine_y2 = 20

	solid_x1 = -28
	solid_y1 = -28
	solid_x2 = 28
	solid_y2 = 28


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if state == STATE_HIDDEN:
		if attack_source < AttackSource.PLAYER_EXPLOSION and hit_rect(x1, y1, x2, y2):
			_start_tipping(true)
			return true
	else:
		if (attack_source == AttackSource.PLAYER_WEAPON
				or (state == STATE_STATIONARY
					and attack_source == AttackSource.TRAVELING_EXPLOSION)) \
				and hit_rect(x1, y1, x2, y2):
			do_remove()
			Explosion.new(x, y)
			main.add_points(points)
			return true
	return false


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	if state == STATE_HIDDEN:
		return false
	return super.bullet_attack(x1, y1, x2, y2)


func bump(x1: float, y1: float, x2: float, y2: float, invincible: bool) -> bool:
	if state == STATE_HIDDEN:
		if game_mode.camera_y < y and is_mine_rect(x1, y1, x2, y2):
			_start_tipping(false)
	else:
		if is_mine_rect(x1, y1, x2, y2):
			do_remove()
			Explosion.new(x, y)
			main.add_points(points)
			return not invincible
	return false


func render() -> void:
	match state:
		STATE_TIPPING, STATE_STATIONARY:
			main.draw_rotated(main.columns[0], x, y, angle)
		STATE_ROLLING:
			main.draw_rotated(main.columns[0], x, y, angle)
			# Two scrolling copies clipped to the barrel give the rolling
			# surface texture.
			if left:
				main.set_clip(x - 22, y - 23, 56, 48)
				main.draw(main.columns[1], x - 46, y - 84 + rotation_offset)
				main.draw(main.columns[1], x - 46, y - 28 + rotation_offset)
				main.clear_clip()
			else:
				main.set_clip(x - 31, y - 25, 56, 48)
				main.draw(main.columns[0], x - 46, y - 84 + rotation_offset)
				main.draw(main.columns[0], x - 46, y - 28 + rotation_offset)
				main.clear_clip()
