# Port of jackal.BossHelicopterManager: pans the camera in, then releases the
# boss helicopter. The helicopter itself ends the stage when destroyed.
class_name BossHelicopterManager
extends GameElement

var ready: bool
var spawn_delay: int = 91
var spawned: int
var destroyed: int


func init() -> void:
	game_mode.start_boss_camera_pan(self)


func pan_complete() -> void:
	ready = true
	BossHelicopter.new()


func update() -> void:
	pass


func render() -> void:
	pass
