# Port of jackal.AppearingSoldier: spawns a soldier once its position has
# scrolled off the bottom of the screen, so it walks up into view.
class_name AppearingSoldier
extends GameElement


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	layer = 0


func update() -> void:
	if game_mode.camera_y + Main.DISPLAY_HEIGHT < y - 75:
		EnemySoldier.new(x, y, EnemySoldierType.APPEARING)
		do_remove()


func render() -> void:
	pass
