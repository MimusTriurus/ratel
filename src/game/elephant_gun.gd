# Port of jackal.ElephantGun.
#
# The stone elephant head: it swings its aim between three directions, charges
# up a spinning "aster" of sparks, spits a fireball down its trunk and fires a
# missile. Only grenades and missiles hurt it, and it takes three hits.
class_name ElephantGun
extends Enemy

const SPRITE_LEFT := 0
const SPRITE_CENTER := 1
const SPRITE_RIGHT := 2
const SPRITE_DESTROYED := 3

const STATE_AIMING := 0
const STATE_ASTERING := 1
const STATE_NOSE := 2
const STATE_DESTROYED := 3

const AIM_DELAY := 45
const ASTER_DELAY := 23
const NOSE_DELAY := 8

const ASTER_SPINES := 5
const ASTER_RADIUS := 128.0
const ASTER_MAX_OFFSET_ANGLE := 2 * PI / ASTER_SPINES
const INVERSE_ASTER_DELAY := 1.0 / float(ASTER_DELAY)
const FIREBALL_SPEED := 6.0

const HITS := 3

var sprite_index: int = SPRITE_CENTER
var destroyed: bool
var state: int
var delay: int
var target_direction: int
var asters: Array[Vector2] = []
var fireball_x: float
var fireball_y: float
var fireball_vx: float
var left: bool
var hits: int
var player: Player


func _init(p_x: float, p_y: float, p_left: bool) -> void:
	super()
	x = p_x
	y = p_y
	left = p_left
	asters.resize(ASTER_SPINES)
	_start_aiming()


func init() -> void:
	super.init()

	player = game_mode.player

	layer = 2

	hit_x1 = 8
	hit_y1 = 8
	hit_x2 = 88
	hit_y2 = 88

	explosion_x = 48
	explosion_y = 48

	points = 3000


func _start_astering() -> void:
	state = STATE_ASTERING
	delay = ASTER_DELAY
	var offset_angle := ASTER_MAX_OFFSET_ANGLE * main.random.randf()
	for i in ASTER_SPINES:
		var a := offset_angle + ASTER_MAX_OFFSET_ANGLE * i
		asters[i] = Vector2(cos(a), sin(a))


func _start_nosing() -> void:
	state = STATE_NOSE
	delay = NOSE_DELAY
	fireball_vx = FIREBALL_SPEED * (sprite_index - 1)
	fireball_x = x + 48
	fireball_y = y + 36


func _start_aiming() -> void:
	state = STATE_AIMING
	delay = 8 + main.random.randi_range(0, 2 * AIM_DELAY - 1)
	target_direction = main.random.randi_range(0, 2)


func _fire() -> void:
	match sprite_index:
		0:
			ElephantMissile.new(x + 4, y + 81, 135, left)
		1:
			ElephantMissile.new(x + 48, y + 86, 90, left)
		2:
			ElephantMissile.new(x + 93, y + 81, 45, left)


func update() -> void:
	# Without missiles the player has to drive much closer, so the hit box is
	# extended to make the fight winnable.
	hit_y2 = 88 if main.has_missiles else 128

	match state:
		STATE_AIMING:
			delay -= 1
			if delay == 0:
				if sprite_index < target_direction:
					sprite_index += 1
					delay = AIM_DELAY
				elif sprite_index > target_direction:
					sprite_index -= 1
					delay = AIM_DELAY
				else:
					_start_astering()
		STATE_ASTERING:
			delay -= 1
			if delay == 0:
				_start_nosing()
		STATE_NOSE:
			fireball_x += fireball_vx
			if sprite_index == 1:
				fireball_y += FIREBALL_SPEED + 2
			else:
				fireball_y += FIREBALL_SPEED
			delay -= 1
			if delay == 0:
				_fire()
				_start_aiming()


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if state == STATE_DESTROYED or attack_source != AttackSource.PLAYER_WEAPON \
			or not hit_rect(x1, y1, x2, y2):
		return false

	main.play_hit_explode_sound()
	hits += 1
	if hits == HITS:
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
		state = STATE_DESTROYED
		sprite_index = SPRITE_DESTROYED
	else:
		# A non-fatal hit ripples a 3x3 grid of small delayed explosions up
		# the face.
		for i in 3:
			var Y := y + 76 - (i << 5)
			for j in 3:
				Explosion.delayed(
					x + (j << 5) + 12 + main.random.randi_range(0, 7),
					Y + main.random.randi_range(0, 7), true, (i + 1) * 4, 0.5)
	return true


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	return state != STATE_DESTROYED and hit_rect(x1, y1, x2, y2)


func render() -> void:
	var y_offset := 0.0
	if sprite_index == 0 or sprite_index == 2:
		y_offset = 4
	main.draw(main.elephant_guns[sprite_index], x, y - y_offset)

	match state:
		STATE_ASTERING:
			var mag := delay * INVERSE_ASTER_DELAY
			var scale := 1.0 - mag
			mag *= ASTER_RADIUS
			for i in ASTER_SPINES:
				main.draw_centered_scaled(main.elephant_guns[4],
					x + 48 + mag * asters[i].x,
					y + 36 + mag * asters[i].y - y_offset,
					scale, scale)
		STATE_NOSE:
			match sprite_index:
				0:
					main.draw(main.elephant_guns[7], x - 4, y + 48 - y_offset)
				1:
					main.draw(main.elephant_guns[5], x + 36, y + 60 - y_offset)
				2:
					main.draw(main.elephant_guns[6], x + 60, y + 48 - y_offset)
			main.draw_centered(main.elephant_guns[4], fireball_x, fireball_y - y_offset)
