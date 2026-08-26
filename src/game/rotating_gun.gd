# Port of jackal.RotatingGun.
#
# Tracks the player, fires a burst of group_size shots with a recoil animation
# between each, then pauses. The original distinguishes three constructors;
# the make_* helpers below stand in for them.
class_name RotatingGun
extends Enemy

const TYPE_GRAY := 0
const TYPE_GREEN := 1
const TYPE_BROWN := 2

const RECOIL_DURATION := 17
const RECOIL_AMPLITUDE := 8.0
const PAUSE_AFTER_RECOIL := 17
const PAUSE_BETWEEN_GROUPS := 50
const GROUP_SIZE := 3
const ROTATION_SPEED := 0.9
const BULLET_DISTANCE := 400.0
const GARAGE_BULLET_DISTANCE := 464.0
const BULLET_TRAVEL_TIME := int(BULLET_DISTANCE / EnemyBullet.SPEED)
const GARAGE_BULLET_TRAVEL_TIME := int(GARAGE_BULLET_DISTANCE / EnemyBullet.SPEED)
const YELLOW_BULLET_SPEED := 1.25

const STATE_FIRING := 0
const STATE_PAUSED_BETWEEN_FIRING := 1
const STATE_TRACKING := 2

static var RECOILS: PackedFloat32Array = PackedFloat32Array()

var state: int = STATE_PAUSED_BETWEEN_FIRING
var angle: float = 90
var recoil: float
var pause: int
var group: int
var group_size: int = GROUP_SIZE
var recoil_index: int
var white: bool
var boss_garage_manager = null
var type: int
var sprites: Array[Spr]


static func _static_init() -> void:
	RECOILS.resize(RECOIL_DURATION)
	for i in range(1, RECOIL_DURATION + 1):
		RECOILS[i - 1] = RECOIL_AMPLITUDE * sin(i * PI / (RECOIL_DURATION + 1))


func _init(p_x: float, p_y: float, p_type: int, p_white: bool,
		p_group_size: int, p_garage_manager) -> void:
	super()
	x = p_x
	y = p_y
	type = p_type
	white = p_white
	group_size = p_group_size
	boss_garage_manager = p_garage_manager
	match p_type:
		TYPE_GREEN:
			sprites = main.green_guns
		TYPE_BROWN:
			sprites = main.brown_guns
		_:
			sprites = main.gray_guns


static func make_gray(p_x: float, p_y: float, p_white: bool) -> RotatingGun:
	return RotatingGun.new(p_x, p_y, TYPE_GRAY, p_white, GROUP_SIZE, null)


static func make_typed(p_x: float, p_y: float, p_type: int) -> RotatingGun:
	return RotatingGun.new(p_x, p_y, p_type, p_type != TYPE_BROWN, 1, null)


static func make_garage(p_x: float, p_y: float, p_manager,
		p_white: bool) -> RotatingGun:
	return RotatingGun.new(p_x, p_y, TYPE_GRAY, p_white, 2, p_manager)


func init() -> void:
	super.init()

	layer = 3

	bullet_hits = 3

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
	solid_x1 = -64
	solid_y1 = -64
	solid_x2 = 64
	solid_y2 = 64

	points = 500


func update() -> void:
	match state:
		STATE_FIRING:
			recoil_index -= 1
			if recoil_index < 0:
				recoil = 0
				group += 1
				if group == group_size:
					state = STATE_TRACKING
					pause = PAUSE_BETWEEN_GROUPS
					group = 0
				else:
					state = STATE_PAUSED_BETWEEN_FIRING
					pause = PAUSE_AFTER_RECOIL
			else:
				recoil = RECOILS[recoil_index]
		STATE_PAUSED_BETWEEN_FIRING:
			if pause > 0:
				pause -= 1
			else:
				_fire()
		STATE_TRACKING:
			if pause > 0:
				pause -= 1
			var player := game_mode.player
			var target_angle := rad_to_deg(atan2(player.y - y, player.x - x))
			var delta_angle := fmod(target_angle - angle + 180, 360.0)
			if delta_angle < 0:
				delta_angle += 180
			else:
				delta_angle -= 180
			if absf(delta_angle) < ROTATION_SPEED:
				angle = target_angle
				if pause == 0:
					_fire()
			else:
				if delta_angle < 0:
					angle -= ROTATION_SPEED
				else:
					angle += ROTATION_SPEED
			# Yellow guns are mounted and cannot swing past the horizontal.
			if not white:
				if angle < 45:
					angle = 45
				elif angle > 135:
					angle = 135


func _fire() -> void:
	state = STATE_FIRING
	recoil_index = RECOIL_DURATION - 1
	var ang := deg_to_rad(angle)
	var c := cos(ang)
	var s := sin(ang)
	var travel := GARAGE_BULLET_TRAVEL_TIME if boss_garage_manager != null \
		else BULLET_TRAVEL_TIME
	if white:
		EnemyBullet.new(x + 60 * c, y + 60 * s, c, s, travel,
			EnemyBullet.SPRITE_WHITE)
	else:
		EnemyBullet.new(x + 60 * c, y + 60 * s,
			YELLOW_BULLET_SPEED * c, YELLOW_BULLET_SPEED * s, travel,
			EnemyBullet.SPRITE_YELLOW)


func render() -> void:
	main.draw_rotated_offset(sprites[0 if recoil == 0 else 1],
		x, y, -28, recoil - 60, angle + 90)
