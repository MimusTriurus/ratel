# Port of jackal.Submarine.
#
# Cycles between submerged (a faint shadow that creeps upstream), surfacing,
# firing a missile and diving again. It can only be hurt once mostly surfaced.
class_name Submarine
extends Enemy

const STATE_SUBMERGED := 0
const STATE_RISING := 1
const STATE_SHOOTING := 2
const STATE_LOWERING := 3

const MINIMUM_ALPHA := 0.3
const MAXIMUM_ALPHA := 0.6

const SUBMERGED_DELAY := 2 * 91
const ELEVATION_DELAY := 69
const SHOOT_DELAY := 91 + 68
const MOVE_SPEED := 0.775
const MOVES := 3

var player: Player
var state: int = STATE_SUBMERGED
var delay: int = 91
var height: int = 0
var alpha: float = MINIMUM_ALPHA
var moveable: bool
var moves: int = MOVES


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	super.init()

	player = game_mode.player

	layer = 3

	bullet_hits = 8

	hit_x1 = -20
	hit_y1 = -60
	hit_x2 = 20
	hit_y2 = 60

	points = 1000


func _start_rising() -> void:
	state = STATE_RISING
	delay = ELEVATION_DELAY
	moves -= 1


func _start_shooting() -> void:
	state = STATE_SHOOTING
	delay = SHOOT_DELAY
	alpha = MAXIMUM_ALPHA
	height = 3


func _start_lowering() -> void:
	state = STATE_LOWERING
	delay = ELEVATION_DELAY


func _start_submerging() -> void:
	state = STATE_SUBMERGED
	delay = SUBMERGED_DELAY
	if moves >= 0:
		delay += SUBMERGED_DELAY
	height = 0
	alpha = MINIMUM_ALPHA
	moveable = true


func update() -> void:
	match state:
		STATE_SUBMERGED:
			delay -= 1
			if delay <= 0:
				if game_mode.camera_y < y - 64:
					_start_rising()
			elif moveable and moves >= 0:
				y -= MOVE_SPEED
		STATE_RISING:
			delay -= 1
			if delay <= 0:
				_start_shooting()
			else:
				var percent := 1.0 - delay / float(ELEVATION_DELAY)
				height = int(3 * percent)
				alpha = MINIMUM_ALPHA + (MAXIMUM_ALPHA - MINIMUM_ALPHA) * percent
		STATE_SHOOTING:
			delay -= 1
			if delay == SHOOT_DELAY - 68:
				SubmarineMissile.new(x, y)
			elif delay <= 0:
				_start_lowering()
		STATE_LOWERING:
			delay -= 1
			if delay <= 0:
				_start_submerging()
			else:
				var percent := delay / float(ELEVATION_DELAY)
				height = int(3 * percent)
				alpha = MINIMUM_ALPHA + (MAXIMUM_ALPHA - MINIMUM_ALPHA) * percent


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if height > 1 and attack_source < AttackSource.PLAYER_EXPLOSION \
			and hit_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x, y)
		main.add_points(points)
		return true
	return false


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	if not (height > 1 and hit_rect(x1, y1, x2, y2)):
		return false
	bullet_hits -= 1
	if bullet_hits <= 0:
		do_remove()
		Explosion.new(x, y)
		main.add_points(points)
	return true


func render() -> void:
	main.draw(main.submarines[0], x - 20, y - 128, alpha)
	if height > 0:
		main.draw_centered(main.submarines[height], x, y)
