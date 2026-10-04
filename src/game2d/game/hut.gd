# Port of jackal.Hut. A hut or shack releases a weapon-carrying prisoner; the
# tank shack variant releases a gray tank instead.
class_name Hut
extends Enemy

var group_index: int
var shack: bool
var tank: bool


func _init(p_x: float, p_y: float, p_shack: bool, p_tank: bool) -> void:
	super()
	x = p_x
	y = p_y
	shack = p_shack
	tank = p_tank

	var X := int(p_x) >> 5
	var Y := int(p_y) >> 5

	if p_shack:
		group_index = game_mode.groups_map[Y + 3][X + 2]
	else:
		group_index = game_mode.groups_map[Y + 1][X + 1]

	for i in range(5 if p_shack else 4, -1, -1):
		for j in 6:
			game_mode.types_map[Y + i][X + j] = GameMode.TYPE_SOLID


func init() -> void:
	super.init()

	layer = 0

	hit_x1 = 0
	hit_y1 = 0
	hit_x2 = 192
	hit_y2 = 192 if shack else 160


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if attack_source <= AttackSource.TRAVELING_EXPLOSION and hit_rect(x1, y1, x2, y2):
		play_sound_on_remove = false
		main.play_sound(main.hut_sound)
		do_remove()
		Explosion.new(x + (96 if shack else 80), y + 96)
		game_mode.trigger_group(group_index)
		if tank:
			GrayTank.from_shack(x + 86, y + 96)
			main.add_points(500)
		else:
			FriendlySoldier.new_walking(x + 96, y + 48 + (64 if shack else 0),
				FriendlySoldierType.WEAPON_CARRIER, 0, shack)
			main.add_points(300)
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
