# Port of jackal.Fire: a flamethrower jet that grows, detaches and travels,
# then shrinks away. Damage is sampled at six points along the jet.
class_name Fire
extends GameElement

const STATE_GROWING := 0
const STATE_TRAVELING := 1
const STATE_SHRINKING := 2

const SPEED := 3.0
const MAX_LENGTH := 128.0
const TRAVEL_TIME := 60

var vx: float
var vy: float
var dx: float
var dy: float
var length: float
var angle: float
var state: int = STATE_GROWING
var delay: int
var flicker_counter: int
var flicker_index: int
var alpha: float = 1.0
var player: Player
var source_enemy: Enemy


func _init(p_x: float, p_y: float, p_vx: float, p_vy: float, p_angle: float,
		p_enemy: Enemy) -> void:
	super()
	x = p_x
	y = p_y
	dx = p_vx
	dy = p_vy
	vx = SPEED * p_vx
	vy = SPEED * p_vy
	angle = p_angle
	source_enemy = p_enemy

	enemy_bullet = true


func init() -> void:
	layer = 4
	player = game_mode.player


func _attack_along(sign: float) -> void:
	for i in 6:
		var mag := sign * 0.2 * i * length
		player.attack(x + mag * dx, y + mag * dy)


func update() -> void:
	match state:
		STATE_GROWING:
			length += SPEED
			if length >= MAX_LENGTH or source_enemy.remove:
				state = STATE_TRAVELING
				delay = TRAVEL_TIME
			_attack_along(1.0)
		STATE_TRAVELING:
			x += vx
			y += vy
			delay -= 1
			if delay == 0:
				state = STATE_SHRINKING
				x += dx * length
				y += dy * length
				Flame.new(x, y)
			else:
				_attack_along(1.0)
		STATE_SHRINKING:
			alpha *= 0.98
			length -= SPEED
			if length <= 0:
				do_remove()
			_attack_along(-1.0)


func render() -> void:
	flicker_counter += 1
	if flicker_counter == 4:
		flicker_index ^= 1
		flicker_counter = 0
	var index := 0
	var scale := 1.0
	if length < 96:
		scale = length * 0.015625
	else:
		index = 1
		scale = length * 0.0078125
	if state == STATE_SHRINKING:
		scale = -scale
	main.draw_rotated_scaled_xy(main.fires[flicker_index][index],
		x, y, 0, -8, angle, scale, 1, alpha)
