# Port of jackal.AppearingEnemyHelicopter.
class_name AppearingEnemyHelicopter
extends GameElement


func _init(p_y: float) -> void:
	super()
	y = p_y


func init() -> void:
	layer = 0


func update() -> void:
	if game_mode.camera_y + Main.DISPLAY_HEIGHT < y - 60:
		EnemyHelicopter.new(false)
		do_remove()


func render() -> void:
	pass
