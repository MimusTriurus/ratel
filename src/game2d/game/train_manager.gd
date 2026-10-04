# Port of jackal.TrainManager: spawns the whole train once its position has
# scrolled off the bottom of the screen.
class_name TrainManager
extends GameElement

const CARS := 6


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	pass


func update() -> void:
	if y > game_mode.camera_y + Main.SCREEN_HEIGHT:
		do_remove()
		for i in CARS:
			Train.new(x + (0 if i == 0 else 4), y + (i << 7), i == 0)


func render() -> void:
	pass
