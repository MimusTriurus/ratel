# Port of jackal.Star: the power-up revealed by shooting an InvisibleStar.
class_name Star
extends Enemy

const SPRITE_BROWN := 0
const SPRITE_GRAY := 1
const SPRITE_GREEN := 2
const SPRITE_YELLOW := 3

const TYPE_BROWN := 0
const TYPE_FLASHING := 1
const TYPE_GREEN := 2

var type: int
var flashing_index: int


func _init(p_x: float, p_y: float, p_type: int) -> void:
	super()
	x = p_x
	y = p_y
	type = p_type


func init() -> void:
	super.init()

	layer = 0

	hit_x1 = -32
	hit_y1 = -32
	hit_x2 = 32
	hit_y2 = 32

	mine = true
	mine_x1 = -8
	mine_y1 = -8
	mine_x2 = 8
	mine_y2 = 8

	solid = true
	solid_x1 = -32
	solid_y1 = -32
	solid_x2 = 32
	solid_y2 = 32


# Collecting a star never kills the player, so this always reports no bump.
func bump(x1: float, y1: float, x2: float, y2: float, _invincible: bool) -> bool:
	if is_mine_rect(x1, y1, x2, y2):
		play_sound_on_remove = false
		do_remove()
		match type:
			TYPE_BROWN:
				main.play_hit_explode_sound()
				game_mode.destroy_all_within_frame()
			TYPE_FLASHING:
				game_mode.player.collect_flashing_star()
			TYPE_GREEN:
				main.gain_extra_life()
	return false


func attack(_x1: float, _y1: float, _x2: float, _y2: float,
		_attack_source: int) -> bool:
	return false


func bullet_attack(_x1: float, _y1: float, _x2: float, _y2: float) -> bool:
	return false


func update() -> void:
	pass


func render() -> void:
	match type:
		TYPE_BROWN:
			main.draw(main.stars[SPRITE_BROWN], x - 32, y - 32)
		TYPE_GREEN:
			main.draw(main.stars[SPRITE_GREEN], x - 32, y - 32)
		TYPE_FLASHING:
			main.draw(main.stars[flashing_index], x - 32, y - 32)
			flashing_index -= 1
			if flashing_index < 0:
				flashing_index = 3
