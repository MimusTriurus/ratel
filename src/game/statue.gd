# Port of jackal.Statue: flashes its eyes, opens its mouth and spits a missile.
class_name Statue
extends Enemy

const PAUSE_TIME := 91
const EYES_FLASHING_TIME := 45
const MOUTH_OPEN_TIME := 45
const MISSILE_TIME := 35

const TYPE_NONE := 0
const TYPE_LEFT := 1
const TYPE_RIGHT := 2

const STATE_PAUSED := 0
const STATE_EYES_FLASHING := 1
const STATE_MOUTH_OPEN := 2

var type: int
var group_index: int
var state: int = STATE_PAUSED
var delay: int = PAUSE_TIME
var eyes_visible: int


func _init(p_x: float, p_y: float, p_type: int) -> void:
	super()
	x = p_x
	y = p_y
	type = p_type

	var X := int(p_x) >> 5
	var Y := int(p_y) >> 5

	# The left statue starts out of phase with the right one.
	if p_type == TYPE_LEFT:
		delay += 108

	group_index = game_mode.groups_map[Y + 1][X + 1]


func init() -> void:
	super.init()

	layer = 3

	hit_x1 = 0
	hit_y1 = 0
	hit_x2 = 96
	hit_y2 = 128


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if (attack_source == AttackSource.PLAYER_WEAPON
			or attack_source == AttackSource.TRAVELING_EXPLOSION) \
			and hit_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x + 48, y + 64)
		game_mode.trigger_group(group_index)
		main.add_points(800)
		return true
	return false


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	return hit_rect(x1, y1, x2, y2)


func update() -> void:
	if type == TYPE_NONE:
		return
	match state:
		STATE_PAUSED:
			delay -= 1
			if delay == 0:
				state = STATE_EYES_FLASHING
				delay = EYES_FLASHING_TIME
		STATE_EYES_FLASHING:
			delay -= 1
			if delay == 0:
				state = STATE_MOUTH_OPEN
				delay = MOUTH_OPEN_TIME
		STATE_MOUTH_OPEN:
			if delay == MISSILE_TIME:
				StatueMissile.new(x, y, type == TYPE_RIGHT)
			delay -= 1
			if delay == 0:
				state = STATE_PAUSED
				delay = PAUSE_TIME


func render() -> void:
	match state:
		STATE_EYES_FLASHING:
			if eyes_visible < 2:
				main.draw(main.statue_blue_eyes, x + 32, y + 64)
			eyes_visible += 1
			if eyes_visible == 4:
				eyes_visible = 0
		STATE_MOUTH_OPEN:
			main.draw(main.statue_blue_mouth, x + 32, y + 96)
