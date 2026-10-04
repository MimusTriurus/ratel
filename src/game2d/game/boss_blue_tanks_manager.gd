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
			# The boss pan leaves camera_y at 0, so these are screen
			# coordinates: 52 px beyond the top or bottom edge, off-screen, and
			# the tank drives in from there. The original wrote the bottom one
			# as 1012, which was 960 + 52 -- derived now, or a taller frame puts
			# the spawn in plain view. sx is a position in the arena, not an
			# edge, and stays as it was.
			var sx: float = 640 if main.random.randi_range(0, 1) == 0 else 1408
			var from_top := main.random.randi_range(0, 1) == 0
			var sy: float = -52.0 if from_top else Main.SCREEN_HEIGHT + 52.0
			BossBlueTank.new(sx, sy, self)


func blue_tank_destroyed() -> void:
	destroyed += 1
	if destroyed == TANKS:
		game_mode.destroy_all()
		game_mode.mark_stage_completed()


func render() -> void:
	pass
