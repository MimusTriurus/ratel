# Port of jackal.EnemyBullet.
#
# The original has three constructors that differ only in which sprite is used
# and whether the direction is pre-scaled; SPRITE_* and multiply_speed cover
# all three.
class_name EnemyBullet
extends GameElement

const SPEED := 2.5
const MARGIN := 16.0

const SPRITE_CANNONBALL := 0
const SPRITE_YELLOW := 1
const SPRITE_WHITE := 2

var travel_time: int
var vx: float
var vy: float
var sprite: Spr
var player: Player


func _init(p_x: float, p_y: float, dx: float, dy: float, p_travel_time: int,
		sprite_kind: int = SPRITE_CANNONBALL, multiply_speed: bool = true) -> void:
	super()
	x = p_x
	y = p_y
	if multiply_speed:
		vx = SPEED * dx
		vy = SPEED * dy
	else:
		vx = dx
		vy = dy
	travel_time = p_travel_time
	match sprite_kind:
		SPRITE_WHITE:
			sprite = main.white_bullet
		SPRITE_YELLOW:
			sprite = main.yellow_bullet
		_:
			sprite = main.cannonball

	enemy_bullet = true


func init() -> void:
	layer = 4
	player = game_mode.player


func update() -> void:
	x += vx
	y += vy

	if game_mode.is_outside_of_frame_rect(x - MARGIN, y - MARGIN,
			x + MARGIN, y + MARGIN):
		do_remove()
		return

	travel_time -= 1
	if travel_time < 0 or game_mode.is_solid(x, y) or player.attack(x, y):
		do_remove()
		BulletHit.new(x, y)


func render() -> void:
	main.draw_centered(sprite, x, y)
