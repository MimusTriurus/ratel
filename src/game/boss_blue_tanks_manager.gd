# Port of jackal.BossBlueTanksManager: pans the camera to the arena, then feeds
# in four tanks from alternating corners.
class_name BossBlueTanksManager
extends GameElement

const SPAWN_DELAY := 3 * 91
const TANKS := 4

var ready: bool
var spawn_delay: int = 91
var spawned: int
var destroyed: int


func init() -> void:
	game_mode.start_boss_camera_pan(self)


func pan_complete() -> void:
	ready = true


func update() -> void:
	if not ready:
		return

	if spawned < TANKS:
		spawn_delay -= 1
		if spawn_delay == 0:
			spawned += 1
			spawn_delay = SPAWN_DELAY
			var sx: float = 640 if main.random.randi_range(0, 1) == 0 else 1408
			var sy: float = -52 if main.random.randi_range(0, 1) == 0 else 1012
			BossBlueTank.new(sx, sy, self)


func blue_tank_destroyed() -> void:
	destroyed += 1
	if destroyed == TANKS:
		game_mode.destroy_all()
		game_mode.mark_stage_completed()


func render() -> void:
	pass
