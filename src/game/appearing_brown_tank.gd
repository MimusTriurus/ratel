# Port of jackal.AppearingBrownTank: holds a tank until its spawn point has
# scrolled off the bottom, so it drives up into view.
class_name AppearingBrownTank
extends GameElement


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	layer = 0


func update() -> void:
	if game_mode.camera_y + Main.DISPLAY_HEIGHT < y - 48:
		var tank := BrownTank.new(x, y)
		tank.target_angle = 270
		tank.display_angle = 270
		do_remove()


func render() -> void:
	pass
