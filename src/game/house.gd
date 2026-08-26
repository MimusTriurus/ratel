# Port of jackal.House: a POW building. Blowing it open swaps in the ruined
# tiles and starts the HELP bubble that releases a prisoner.
class_name House
extends Enemy

var group_index: int
var left: bool


func _init(p_x: float, p_y: float, p_left: bool) -> void:
	super()
	x = p_x
	y = p_y
	left = p_left

	var X := int(p_x) >> 5
	var Y := int(p_y) >> 5

	group_index = game_mode.groups_map[Y + 2][X + (0 if p_left else 5)]

	# The building footprint is made solid at spawn time.
	for i in 6:
		for j in 6:
			game_mode.types_map[Y + i][X + j] = GameMode.TYPE_SOLID


func init() -> void:
	super.init()

	layer = 0

	hit_x1 = 0
	hit_y1 = 0
	hit_x2 = 192
	hit_y2 = 192


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if attack_source <= AttackSource.TRAVELING_EXPLOSION and hit_rect(x1, y1, x2, y2):
		play_sound_on_remove = false
		main.play_sound(main.hut_sound)
		do_remove()
		Explosion.new(x + 96, y + 96)
		game_mode.trigger_group(group_index)
		Help.new(x + 96, y + 84, left)
		main.add_points(800)
		return true
	return false


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	return hit_rect(x1, y1, x2, y2)


func explode() -> void:
	pass


func update() -> void:
	pass


func render() -> void:
	pass
