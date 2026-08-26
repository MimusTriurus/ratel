# Port of jackal.Laser: the lethal beam itself. It is invisible (LasersManager
# draws it) and exists only as a tall, one-pixel-wide kill box.
class_name Laser
extends Enemy


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y
	play_sound_on_remove = false

	if game_mode.camera_y <= p_y + 896:
		main.play_sound(main.laser_sound)


func init() -> void:
	super.init()

	mine = true
	mine_x1 = -1
	mine_y1 = 0
	mine_x2 = 1
	mine_y2 = 832

	solid = true
	solid_x1 = -16
	solid_y1 = 0
	solid_x2 = 16
	solid_y2 = 832


func explode() -> void:
	pass


func bump(x1: float, y1: float, x2: float, y2: float, invincible: bool) -> bool:
	if invincible:
		return false
	return is_mine_rect(x1, y1, x2, y2)


func attack(_x1: float, _y1: float, _x2: float, _y2: float,
		_attack_source: int) -> bool:
	return false


func bullet_attack(_x1: float, _y1: float, _x2: float, _y2: float) -> bool:
	return false


func update() -> void:
	pass


func render() -> void:
	pass
