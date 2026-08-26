# Port of jackal.BossStatue: like a Statue but fires homing missiles and takes
# three grenade hits, spraying delayed explosions up its face in between.
class_name BossStatue
extends Enemy

const PAUSE_TIME := 4 * 91
const EYES_FLASHING_TIME := 45
const MOUTH_OPEN_TIME := 45
const MISSILE_TIME := 35

const STATE_PAUSED := 0
const STATE_EYES_FLASHING := 1
const STATE_MOUTH_OPEN := 2

const HITS := 3

var type: int
var group_index: int
var state: int = STATE_PAUSED
var delay: int = 91
var eyes_visible: int
var hits: int
var boss_statues_manager = null


func _init(p_x: float, p_y: float, start_delay: int, p_manager) -> void:
	super()
	x = p_x
	y = p_y
	boss_statues_manager = p_manager

	var X := int(p_x) >> 5
	var Y := int(p_y) >> 5

	group_index = game_mode.groups_map[Y + 1][X + 1]

	delay += start_delay


func init() -> void:
	super.init()

	layer = 3

	hit_x1 = 8
	hit_y1 = 0
	hit_x2 = 88
	hit_y2 = 128


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if attack_source != AttackSource.PLAYER_WEAPON or not hit_rect(x1, y1, x2, y2):
		return false

	hits += 1
	if hits == HITS:
		do_remove()
		boss_statues_manager.statue_destroyed()
		Explosion.new(x + 48, y + 64)
		game_mode.trigger_group(group_index)
		main.add_points(800)
	else:
		main.play_hit_explode_sound()
		# Explosions climb the statue from where it was hit.
		var X := 0.5 * (x1 + x2)
		if X < x + 32:
			X = x + 32
		elif X > x + 64:
			X = x + 64
		for i in 5:
			Explosion.delayed(
				X + main.random.randi_range(0, 7) - 4,
				y + 156 + main.random.randi_range(0, 7) - (i << 5),
				true, (i + 1) * 4, 0.5)
	return true


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	return hit_rect(x1, y1, x2, y2)


func update() -> void:
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
				StatueSeekerMissile.new(x, y)
			delay -= 1
			if delay == 0:
				state = STATE_PAUSED
				delay = PAUSE_TIME


func render() -> void:
	match state:
		STATE_EYES_FLASHING:
			if eyes_visible < 2:
				main.draw(main.statue_white_eyes, x + 32, y + 64)
			eyes_visible += 1
			if eyes_visible == 4:
				eyes_visible = 0
		STATE_MOUTH_OPEN:
			main.draw(main.statue_white_mouth, x + 32, y + 96)
