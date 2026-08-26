# Port of jackal.BossSuperTankGun: the turret riding on the super tank. It
# cannot be damaged; the tank body is the target.
class_name BossSuperTankGun
extends Enemy

const RECOIL_DURATION := 17
const RECOIL_AMPLITUDE := 8.0
const PAUSE_AFTER_RECOIL := 17
const PAUSE_BETWEEN_GROUPS := 50
const GROUP_SIZE := 3
const ROTATION_SPEED := 0.9
const BULLET_DISTANCE := 480.0
const YELLOW_BULLET_SPEED := 1.75 * EnemyBullet.SPEED
const BULLET_TRAVEL_TIME := int(BULLET_DISTANCE / YELLOW_BULLET_SPEED)
const X_OFFSET := 244.0
const Y_OFFSET := 88.0

static var RECOILS: PackedFloat32Array = PackedFloat32Array()

var state: int = RotatingGun.STATE_PAUSED_BETWEEN_FIRING
var angle: float = 90
var recoil: float
var pause: int = 2 * 91
var group: int
var group_size: int = GROUP_SIZE
var recoil_index: int
var boss_super_tank = null


static func _static_init() -> void:
	RECOILS.resize(RECOIL_DURATION)
	for i in range(1, RECOIL_DURATION + 1):
		RECOILS[i - 1] = RECOIL_AMPLITUDE * sin(i * PI / (RECOIL_DURATION + 1))


func _init(p_boss_super_tank) -> void:
	super()
	boss_super_tank = p_boss_super_tank


func init() -> void:
	super.init()
	layer = 3


func update() -> void:
	x = boss_super_tank.x + X_OFFSET
	y = boss_super_tank.y + Y_OFFSET

	match state:
		RotatingGun.STATE_FIRING:
			recoil_index -= 1
			if recoil_index < 0:
				recoil = 0
				group += 1
				if group == group_size:
					state = RotatingGun.STATE_TRACKING
					pause = PAUSE_BETWEEN_GROUPS
					group = 0
				else:
					state = RotatingGun.STATE_PAUSED_BETWEEN_FIRING
					pause = PAUSE_AFTER_RECOIL
			else:
				recoil = RECOILS[recoil_index]
		RotatingGun.STATE_PAUSED_BETWEEN_FIRING:
			if pause > 0:
				pause -= 1
			else:
				_fire()
		RotatingGun.STATE_TRACKING:
			if pause > 0:
				pause -= 1
			var player := game_mode.player
			var target_angle := rad_to_deg(atan2(
				player.y - (boss_super_tank.y + Y_OFFSET),
				player.x - (boss_super_tank.x + X_OFFSET)))
			var delta_angle := fmod(target_angle - angle + 180, 360.0)
			if delta_angle < 0:
				delta_angle += 180
			else:
				delta_angle -= 180
			if absf(delta_angle) < ROTATION_SPEED:
				angle = target_angle
				if pause == 0:
					_fire()
			elif delta_angle < 0:
				angle -= ROTATION_SPEED
			else:
				angle += ROTATION_SPEED

	if boss_super_tank.remove:
		do_remove()


func _fire() -> void:
	state = RotatingGun.STATE_FIRING
	recoil_index = RECOIL_DURATION - 1
	var ang := deg_to_rad(angle)
	var c := cos(ang)
	var s := sin(ang)
	# The shell inherits the tank's horizontal velocity.
	EnemyBullet.new(
		boss_super_tank.x + X_OFFSET + 93 * c,
		boss_super_tank.y + Y_OFFSET + 93 * s,
		YELLOW_BULLET_SPEED * c + boss_super_tank.vx,
		YELLOW_BULLET_SPEED * s,
		BULLET_TRAVEL_TIME, EnemyBullet.SPRITE_YELLOW, false)


func attack(_x1: float, _y1: float, _x2: float, _y2: float,
		_attack_source: int) -> bool:
	return false


func bullet_attack(_x1: float, _y1: float, _x2: float, _y2: float) -> bool:
	return false


func render() -> void:
	main.draw_rotated_offset(
		main.super_guns[0 if boss_super_tank.color_index == 0 else 1],
		boss_super_tank.x + X_OFFSET, boss_super_tank.y + Y_OFFSET,
		-recoil - 34, -32, angle)
