# Port of jackal.CannonTruck: fires a spreading three-round burst, one, then
# two, then two shells, with a recoil frame between each.
class_name CannonTruck
extends Enemy

const STATE_SLEEPING := 0
const STATE_RECOILING := 1

const SHOOT_DELAY := 91
const RECOIL_DELAY := 16
const RECOIL_HALF := 8

const BULLET_ORIGIN_X := 48.0
const BULLET_ORIGIN_Y := 25.0

const BULLET_TRAVEL_TIME := 137
const BULLET_SPEED := 2.0
const BULLET_ANGLE := PI / 18.0  # 10 degrees

static var DIRS: Array = []

var direction_index: int
var right: bool
var state: int = STATE_SLEEPING
var delay: int = 1
var fires: int
var ready: bool


static func _static_init() -> void:
	var base := PI / 4.0
	DIRS = [
		[Vector2(BULLET_SPEED * cos(base), BULLET_SPEED * sin(base))],
		[
			Vector2(BULLET_SPEED * cos(base - BULLET_ANGLE),
				BULLET_SPEED * sin(base - BULLET_ANGLE)),
			Vector2(BULLET_SPEED * cos(base + BULLET_ANGLE),
				BULLET_SPEED * sin(base + BULLET_ANGLE)),
		],
		[
			Vector2(BULLET_SPEED * cos(base - 2 * BULLET_ANGLE),
				BULLET_SPEED * sin(base - 2 * BULLET_ANGLE)),
			Vector2(BULLET_SPEED * cos(base + 2 * BULLET_ANGLE),
				BULLET_SPEED * sin(base + 2 * BULLET_ANGLE)),
		],
	]


func _init(p_x: float, p_y: float, p_right: bool) -> void:
	super()
	x = p_x
	y = p_y
	right = p_right
	direction_index = 0 if p_right else 1

	explosion_x = 48
	explosion_y = 48


func init() -> void:
	super.init()

	layer = 3

	bullet_hits = 8

	hit_x1 = 8
	hit_y1 = 8
	hit_x2 = 88
	hit_y2 = 88

	mine = true
	mine_x1 = 8
	mine_y1 = 8
	mine_x2 = 88
	mine_y2 = 88

	solid = true
	solid_x1 = 0
	solid_y1 = 0
	solid_x2 = 96
	solid_y2 = 96

	points = 1500


func _fire() -> void:
	state = STATE_RECOILING
	delay = RECOIL_DELAY

	if fires < DIRS.size():
		for d in DIRS[fires]:
			EnemyBullet.new(x + BULLET_ORIGIN_X, y + BULLET_ORIGIN_Y,
				d.x if right else -d.x, d.y, BULLET_TRAVEL_TIME)
	fires += 1


func update() -> void:
	if not ready:
		if y + 48 > game_mode.camera_y:
			ready = true
		else:
			return

	match state:
		STATE_SLEEPING:
			delay -= 1
			if delay == 0:
				_fire()
		STATE_RECOILING:
			delay -= 1
			if delay == 0:
				if fires == 3:
					state = STATE_SLEEPING
					delay = SHOOT_DELAY
					fires = 0
				else:
					_fire()


func render() -> void:
	if state == STATE_RECOILING and delay > RECOIL_HALF:
		main.draw(main.cannon_truck[direction_index][1], x, y)
	else:
		main.draw(main.cannon_truck[direction_index][0], x, y)
