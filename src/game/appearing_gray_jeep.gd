# Port of jackal.AppearingGrayJeep.
class_name AppearingGrayJeep
extends GameElement


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	layer = 0


func update() -> void:
	if game_mode.camera_y + Main.SCREEN_HEIGHT < y - 48:
		var jeep := GrayJeep.new(x, y)
		jeep.target_angle = 270
		jeep.display_angle = 270
		do_remove()


func render() -> void:
	pass
