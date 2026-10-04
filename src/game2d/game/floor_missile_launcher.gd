# Port of jackal.FloorMissileLauncher: floor panels slide apart, a homing
# missile launches, and they close again. Vulnerable only while open.
class_name FloorMissileLauncher
extends Enemy

const STATE_CLOSED := 0
const STATE_OPENING := 1
const STATE_OPEN := 2
const STATE_CLOSING := 3

const CLOSED_DELAY := 3 * 91
const OPEN_DELAY := 32
const PANEL_SPEED := 2.0

var ready: bool
var state: int = STATE_CLOSED
var delay: int = CLOSED_DELAY
var panel_offset: float


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	super.init()

	layer = 0

	bullet_hits = 10

	hit_x1 = 8
	hit_y1 = 8
	hit_x2 = 88
	hit_y2 = 52

	points = 2000


func update() -> void:
	match state:
		STATE_CLOSED:
			if delay > 0:
				delay -= 1
			if delay == 0 and not game_mode.is_outside_of_frame(x + 48, y + 42):
				state = STATE_OPENING
				panel_offset = 0
		STATE_OPENING:
			panel_offset += PANEL_SPEED
			if panel_offset >= 20:
				state = STATE_OPEN
				panel_offset = 20
				delay = OPEN_DELAY
				SwampMissile.new(x + 48, y + 42)
		STATE_OPEN:
			delay -= 1
			if delay == 0:
				state = STATE_CLOSING
		STATE_CLOSING:
			panel_offset -= PANEL_SPEED
			if panel_offset <= 0:
				state = STATE_CLOSED
				panel_offset = 0
				delay = CLOSED_DELAY


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if state == STATE_CLOSED:
		return false
	if (attack_source == AttackSource.PLAYER_WEAPON
			or attack_source == AttackSource.TRAVELING_EXPLOSION) \
			and hit_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
		return true
	return false


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	if state == STATE_CLOSED:
		return false
	return super.bullet_attack(x1, y1, x2, y2)


func render() -> void:
	if state == STATE_CLOSED:
		main.draw(main.floor_missile_launcher[3], x + 8, y + 8)
		main.draw(main.floor_missile_launcher[1], x + 8, y + 8)
		main.draw(main.floor_missile_launcher[2], x + 8, y + 22)
		main.draw(main.floor_missile_launcher[0], x, y)
	else:
		main.draw(main.floor_missile_launcher[3], x + 8, y + 8)
		main.set_clip(2 + x, 2 + y, 95, 52)
		main.draw(main.floor_missile_launcher[1], x + 8, y + 8 - panel_offset)
		main.draw(main.floor_missile_launcher[2], x + 8, y + 22 + panel_offset)
		main.clear_clip()
		main.draw(main.floor_missile_launcher[0], x, y)
