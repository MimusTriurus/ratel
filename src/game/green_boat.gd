# Port of jackal.GreenBoat: drifts down-left for a while, then holds position
# and keeps firing at the player.
class_name GreenBoat
extends Enemy

const SPRITE_TOGGLE_FRAMES := 12
const BULLET_DELAY := 91
const BULLET_TRAVEL_TIME := 2 * 91
const SPEED := 0.75
const MOVEMENT_TIME := 181

var player: Player
var sprite_index: int
var sprite_index_counter: int
var bullet_delay: int
var movement_delay: int = MOVEMENT_TIME


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	super.init()

	player = game_mode.player

	layer = 3

	bullet_hits = 6

	hit_x1 = -40
	hit_y1 = -40
	hit_x2 = 40
	hit_y2 = 40

	points = 800


func update() -> void:
	if movement_delay > 0:
		movement_delay -= 1
		x -= SPEED
		y += SPEED

	sprite_index_counter -= 1
	if sprite_index_counter < 0:
		sprite_index_counter = SPRITE_TOGGLE_FRAMES
		sprite_index ^= 1

	bullet_delay -= 1
	if bullet_delay < 0:
		bullet_delay = BULLET_DELAY
		var X := x - 16
		var Y := y + 16
		var dx := player.x - X
		var dy := player.y - Y
		var imag := 1.0 / sqrt(dx * dx + dy * dy)
		EnemyBullet.new(X, Y, dx * imag, dy * imag, BULLET_TRAVEL_TIME,
			EnemyBullet.SPRITE_WHITE)


func render() -> void:
	main.draw(main.green_boats[sprite_index], x - 58, y - 64)
