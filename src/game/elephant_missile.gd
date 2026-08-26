# Port of jackal.ElephantMissile: flies until it reaches a fixed row, then
# blows a hole in the wall there by swapping in that tile group.
class_name ElephantMissile
extends GameElement

const SPEED := 6.0
const DIAGONAL_SPEED := SPEED / 1.4142135623730951

var angle: float
var vx: float
var vy: float
var max_y: float
var explosion_offset: float
var tip_x: float
var tip_y: float
var player: Player


func _init(p_x: float, p_y: float, p_angle: int, left: bool) -> void:
	super()
	x = p_x
	y = p_y
	angle = p_angle

	match p_angle:
		45:
			vx = DIAGONAL_SPEED
			vy = DIAGONAL_SPEED
			explosion_offset = 32
			tip_x = 10
			tip_y = 10
		90:
			vx = 0
			vy = SPEED
			if not left:
				explosion_offset = 32
			tip_x = 0
			tip_y = 16
		135:
			vx = -DIAGONAL_SPEED
			vy = DIAGONAL_SPEED
			tip_x = -10
			tip_y = 10

	if p_angle == 90:
		max_y = 908
	else:
		max_y = 598 if main.random.randi_range(0, 1) == 0 else 822

	main.play_sound(main.laser_sound)


func init() -> void:
	layer = 4
	player = game_mode.player


func update() -> void:
	x += vx
	y += vy
	if y >= max_y:
		do_remove()
		var X := int(x) >> 5
		var Y := int(y) >> 5
		game_mode.trigger_group(game_mode.groups_map[Y][X])
		var e := Explosion.new((X << 5) + explosion_offset, (Y << 5) + 32)
		e.set_damages_enemies(false)
	elif player.attack(x + tip_x, y + tip_y):
		do_remove()
		Explosion.new(x + tip_x, y + tip_y)


func render() -> void:
	main.draw_rotated(main.elephant_guns[8], x, y, angle)
