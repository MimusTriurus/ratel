# Port of jackal.Parachute: a paratrooper dropped by the boss helicopter. It is
# flung sideways, then the canopy inflates through six stages before the
# soldier lands.
class_name Parachute
extends GameElement

const STATE_LAUNCH := 0
const STATE_DRIFT := 1
const STATE_DEAD := 2

const SPEED := 2.0
const DRIFT_SPEED := 1.0
const MAX_HORIZONTAL_DRIFT_SPEED := 0.5
const INFLATE_TIME := 32

const INFLATE_INDEX: Array[int] = [0, 1, 1, 2, 2, 3]

# Per stage: starting scale, and how much it changes over the stage.
const INFLATES: Array[Vector2] = [
	Vector2(28.0 / 28.0, 38.0 / 28.0 - 28.0 / 28.0),
	Vector2(38.0 / 48.0, 48.0 / 48.0 - 38.0 / 48.0),
	Vector2(48.0 / 48.0, 56.0 / 48.0 - 48.0 / 48.0),
	Vector2(56.0 / 64.0, 64.0 / 64.0 - 56.0 / 64.0),
	Vector2(64.0 / 64.0, 62.0 / 64.0 - 64.0 / 64.0),
	Vector2(62.0 / 60.0, 60.0 / 60.0 - 62.0 / 60.0),
]

var delay: int
var state: int = STATE_LAUNCH
var vx: float
var inflate: int
var inflate2: int
var boss_helicopter = null
var left: bool


func _init(p_x: float, p_y: float, distance: float, p_left: bool,
		p_boss_helicopter) -> void:
	super()
	x = p_x
	y = p_y
	boss_helicopter = p_boss_helicopter

	delay = int(distance / SPEED)
	vx = -SPEED if p_left else SPEED
	left = p_left


func init() -> void:
	layer = 5


func update() -> void:
	# Killing the helicopter takes its paratroopers with it.
	if boss_helicopter.remove:
		state = STATE_DEAD
		Explosion.new(x, y)
		do_remove()
		return

	match state:
		STATE_LAUNCH:
			x += vx
			delay -= 1
			if delay == 0:
				state = STATE_DRIFT
				delay = 0
				vx = MAX_HORIZONTAL_DRIFT_SPEED \
					+ MAX_HORIZONTAL_DRIFT_SPEED * main.random.randf()
				if left:
					vx = -vx
		STATE_DRIFT:
			y += DRIFT_SPEED
			x += vx
			inflate2 += 1
			delay += 1
			if delay == INFLATE_TIME:
				delay = 0
				inflate += 1
				if inflate > 5:
					var s := EnemySoldier.new(x, y + 16, EnemySoldierType.WALKER)
					s.set_boss_helicopter(boss_helicopter)
					do_remove()


func render() -> void:
	match state:
		STATE_DRIFT:
			var percent := inflate2 / (6.0 * INFLATE_TIME)
			var offset := 64 - 64 * percent
			main.draw_centered_scaled(main.parachutes[4], x + offset, y + offset,
				0.25 + 0.6 * percent, 0.5)
			main.draw_centered_scaled(main.parachutes[INFLATE_INDEX[inflate]], x, y,
				INFLATES[inflate].x + INFLATES[inflate].y
					* (delay / float(INFLATE_TIME)))
		STATE_DEAD:
			pass
		_:
			main.draw_centered_scaled(main.parachutes[4], x + 64, y + 64, 0.25, 0.5)
			main.draw_centered(main.parachutes[0], x, y)
