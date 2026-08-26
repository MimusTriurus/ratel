# Port of jackal.CliffGun: pops out of the cliff face, fires three tracked
# shots and retreats. It can only be destroyed once it is most of the way out.
class_name CliffGun
extends Enemy

const STATE_HIDDEN := 0
const STATE_APPEARING := 1
const STATE_VISIBLE_1 := 2
const STATE_SHOOTING := 3
const STATE_VISIBLE_2 := 4
const STATE_DISAPPEARING := 5

const HIDDEN_TIME := 80
const APPEARING_TIME := 16
const VISIBLE_TIME := 16
const RECOIL_TIME := 28
const DEACTIVE_TIME := RECOIL_TIME * 3

const BULLET_TRAVEL_TIME := 2 * 91
const BULLET_SPEED := 1.5

const RECOIL_MAGNITUDE := 8.0
const DEACTIVATE_DISTANCE := 128.0

static var RECOILS: PackedFloat32Array = PackedFloat32Array()

var state: int = STATE_HIDDEN
var sprite_index: int
var delay: int = HIDDEN_TIME
var shots: int
var player: Player


static func _static_init() -> void:
	RECOILS.resize(RECOIL_TIME)
	for i in RECOIL_TIME:
		var percent := i / float(RECOIL_TIME)
		RECOILS[i] = RECOIL_MAGNITUDE * (0.5 - cos(PI * percent) / 2.0)


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	super.init()

	player = game_mode.player

	layer = 3

	hit_x1 = 8
	hit_y1 = 8
	hit_x2 = 88
	hit_y2 = 56

	points = 1000

	explosion_x = 48
	explosion_y = 32


func update() -> void:
	match state:
		STATE_HIDDEN:
			delay -= 1
			if delay == 0:
				state = STATE_APPEARING
				sprite_index = 1
				delay = APPEARING_TIME
		STATE_APPEARING:
			delay -= 1
			if delay == 0:
				if sprite_index == 1:
					sprite_index = 2
					delay = APPEARING_TIME
				else:
					state = STATE_VISIBLE_1
					sprite_index = 3
					delay = VISIBLE_TIME
		STATE_VISIBLE_1:
			delay -= 1
			if delay == 0:
				# Too close below the gun to be worth firing at.
				if player.y - y < DEACTIVATE_DISTANCE:
					state = STATE_VISIBLE_2
					delay = DEACTIVE_TIME
				else:
					state = STATE_SHOOTING
					shots = 3
					_shoot()
		STATE_SHOOTING:
			delay -= 1
			if delay == 0:
				if shots == 0:
					state = STATE_VISIBLE_2
					delay = VISIBLE_TIME
				else:
					_shoot()
		STATE_VISIBLE_2:
			delay -= 1
			if delay == 0:
				state = STATE_DISAPPEARING
				sprite_index = 2
				delay = APPEARING_TIME
		STATE_DISAPPEARING:
			delay -= 1
			if delay == 0:
				if sprite_index == 2:
					sprite_index = 1
					delay = APPEARING_TIME
				else:
					sprite_index = 0
					state = STATE_HIDDEN
					delay = HIDDEN_TIME


func _shoot() -> void:
	delay = RECOIL_TIME - 1
	shots -= 1
	var X := x + 48
	var Y := y + 36
	var dx := player.x - X
	var dy := player.y - Y
	var imag := BULLET_SPEED / sqrt(dx * dx + dy * dy)
	EnemyBullet.new(X, Y, dx * imag, dy * imag, BULLET_TRAVEL_TIME)


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if sprite_index < 2:
		return false
	if attack_source < AttackSource.PLAYER_EXPLOSION and hit_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
		return true
	return false


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	if state == STATE_HIDDEN:
		return false
	return hit_rect(x1, y1, x2, y2)


func render() -> void:
	main.draw(main.cliff_guns[sprite_index], x, y)
	if sprite_index == 3:
		if state == STATE_SHOOTING:
			main.draw(main.cliff_guns[4], x + 32, y - RECOILS[delay])
		else:
			main.draw(main.cliff_guns[4], x + 32, y)
