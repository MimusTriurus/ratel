# Port of jackal.InvisibleStar: a hidden target that turns into a Star.
class_name InvisibleStar
extends Enemy

var type: int


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


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if attack_source < AttackSource.PLAYER_EXPLOSION and hit_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x, y)
		main.add_points(5000)
		Star.new(x, y, type)
		return true
	return false


func bullet_attack(_x1: float, _y1: float, _x2: float, _y2: float) -> bool:
	return false


func update() -> void:
	pass


func render() -> void:
	pass
