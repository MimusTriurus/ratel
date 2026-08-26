# Port of jackal.Mine. Only becomes visible once the player is close.
class_name Mine
extends Enemy

const VISIBLE_DISTANCE := 300.0
const VISIBLE_DISTANCE2 := VISIBLE_DISTANCE * VISIBLE_DISTANCE

var sprite_index: int
var visible: bool
var player: Player


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y
	player = game_mode.player
	explosion_x = 16
	explosion_y = 16


func init() -> void:
	super.init()

	layer = 0

	hit_x1 = 0
	hit_y1 = 0
	hit_x2 = 32
	hit_y2 = 32

	mine = true
	mine_x1 = 8
	mine_y1 = 8
	mine_x2 = 24
	mine_y2 = 24

	solid = true
	solid_x1 = 0
	solid_y1 = 0
	solid_x2 = 32
	solid_y2 = 32


func update() -> void:
	var dx := player.x - (x + 16)
	var dy := player.y - (y + 16)
	visible = (dx * dx + dy * dy) <= VISIBLE_DISTANCE2


func attack(_x1: float, _y1: float, _x2: float, _y2: float,
		_attack_source: int) -> bool:
	return false


func bullet_attack(_x1: float, _y1: float, _x2: float, _y2: float) -> bool:
	return false


func render() -> void:
	if visible:
		sprite_index += 1
		if sprite_index == 4:
			sprite_index = 0
		main.draw(main.mines[sprite_index], x, y)
