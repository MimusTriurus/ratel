# Port of jackal.Gate: an invisible target that swaps in the "open" tile group
# when hit by a grenade or missile.
class_name Gate
extends Enemy

var group_index: int
var boss_garage_manager = null


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y
	group_index = game_mode.groups_map[int(p_y) >> 5][(int(p_x) >> 5) + 1]


static func for_garage(p_x: float, p_y: float, p_manager) -> Gate:
	var g := Gate.new(p_x, p_y)
	g.boss_garage_manager = p_manager
	return g


func init() -> void:
	super.init()

	layer = 0

	hit_x1 = 0
	hit_y1 = 0
	hit_x2 = 192
	hit_y2 = 128


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if attack_source == AttackSource.PLAYER_WEAPON and hit_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x + 96, y + 64)
		game_mode.trigger_group(group_index)
		if boss_garage_manager != null:
			boss_garage_manager.gate_open()
		return true
	return false


# Bullets are absorbed but do nothing.
func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	return hit_rect(x1, y1, x2, y2)


func explode() -> void:
	pass


func update() -> void:
	pass


func render() -> void:
	pass
