# Port of jackal.Rock.
#
# The boulder rolls along a cliff, drops to the lower level (faked by scaling
# down while moving diagonally) and then rolls to a stop, flattening anything
# it runs over on the way.
class_name Rock
extends Enemy

const STATE_RESTING_HIGH := 0
const STATE_ROLLING_FORWARD_HIGH := 1
const STATE_ROLLING_DOWN := 2
const STATE_ROLLING_FORWARD_LOW := 3
const STATE_RESTING_LOW := 4

const TRIGGER_DISTANCE := 224.0
const HIGH_DISTANCE := 2.0 * 32
const FALL_DISTANCE := 5.0 * 32
const LOW_DISTANCE := 6.0 * 32

const HIGH_TIME := 60
const FALL_TIME := 60
const LOW_TIME := 60

const HIGH_ACCELERATION := (2.0 * HIGH_DISTANCE) / float(HIGH_TIME * HIGH_TIME)
const SCALE_ACCELERATION := -0.5 / float(FALL_TIME * FALL_TIME)

const SQRT2 := 1.4142135623730951
const ISQRT2 := 0.7071067811865476

var player: Player
var angle: float
var scale: float = 1
var v_scale: float
var state: int = STATE_RESTING_HIGH
var vx: float
var delay: int
var rolls_right: bool
var acceleration: float
var mines: Array[Enemy]


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y
	rolls_right = p_x > 32 * 35


func init() -> void:
	super.init()

	mines = game_mode.mines
	player = game_mode.player

	layer = 3

	bullet_hits = 7

	hit_x1 = -24
	hit_y1 = -24
	hit_x2 = 24
	hit_y2 = 24

	mine = true
	mine_x1 = -20
	mine_y1 = -20
	mine_x2 = 20
	mine_y2 = 20

	solid = true
	solid_x1 = -32
	solid_y1 = -32
	solid_x2 = 32
	solid_y2 = 32

	points = 800


func _roll_over_enemies() -> void:
	for i in range(mines.size() - 1, -1, -1):
		var m: Enemy = mines[i]
		if m != self and m.is_mine_rect(x + mine_x1, y + mine_y1,
				x + mine_x2, y + mine_y2):
			m.flatten()


func flatten() -> void:
	if state == STATE_RESTING_LOW:
		explode()


func _roll() -> void:
	if rolls_right:
		x += vx
		angle += 4 * vx
	else:
		x -= vx
		angle -= 4 * vx


func update() -> void:
	match state:
		STATE_RESTING_HIGH:
			if player.y - y <= TRIGGER_DISTANCE \
					and ((rolls_right and player.x > 1024)
						or (not rolls_right and player.x < 1024)):
				state = STATE_ROLLING_FORWARD_HIGH
				delay = HIGH_TIME
		STATE_ROLLING_FORWARD_HIGH:
			vx += HIGH_ACCELERATION
			_roll()
			delay -= 1
			if delay == 0:
				state = STATE_ROLLING_DOWN
				vx *= ISQRT2
				delay = FALL_TIME
				acceleration = 2.0 * (FALL_DISTANCE - vx * FALL_TIME) \
					/ float(FALL_TIME * FALL_TIME)
		STATE_ROLLING_DOWN:
			vx += acceleration
			_roll()
			v_scale += SCALE_ACCELERATION
			scale += v_scale
			y += vx
			delay -= 1
			if delay == 0:
				state = STATE_ROLLING_FORWARD_LOW
				vx *= SQRT2
				delay = LOW_TIME
				acceleration = -vx / float(LOW_TIME)
		STATE_ROLLING_FORWARD_LOW:
			vx += acceleration
			_roll()
			delay -= 1
			if delay == 0:
				state = STATE_RESTING_LOW
			_roll_over_enemies()


func render() -> void:
	main.draw_rotated_offset_scaled(main.rock, x, y, -32, -32, angle, scale)
