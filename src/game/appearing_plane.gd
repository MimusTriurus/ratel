# Port of jackal.AppearingPlane.
class_name AppearingPlane
extends GameElement


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	layer = 0


func update() -> void:
	if game_mode.camera_y + Main.DISPLAY_HEIGHT < y - 48:
		Airplane.upward(x, y)
		do_remove()


func render() -> void:
	pass
