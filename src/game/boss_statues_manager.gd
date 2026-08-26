# Port of jackal.BossStatuesManager: four statues, plus a trickle of brown
# tanks driving up from the bottom while any statue is still standing.
class_name BossStatuesManager
extends GameElement

const MAX_TANKS := 5

var ready: bool
var brown_tank_delay: int = 3 * 91
var statues: int = 4
var tanks: int


func init() -> void:
	game_mode.start_boss_camera_pan(self)


func statue_destroyed() -> void:
	statues -= 1
	if statues == 0:
		game_mode.destroy_all()
		game_mode.mark_stage_completed()


func pan_complete() -> void:
	ready = true
	BossStatue.new(704, 64, 136, self)
	BossStatue.new(864, 64, 45, self)
	BossStatue.new(1024, 64, 91, self)
	BossStatue.new(1184, 64, 0, self)


func tank_created() -> void:
	tanks += 1


func tank_destroyed() -> void:
	tanks -= 1


func update() -> void:
	if not ready:
		return

	if statues > 0:
		brown_tank_delay -= 1
		if brown_tank_delay < 0:
			if tanks >= MAX_TANKS:
				brown_tank_delay = 91
			else:
				brown_tank_delay = 10 * 91
				var sx := game_mode.camera_x \
					+ main.random.randi_range(0, Main.DISPLAY_WIDTH - 1)
				if sx < 352:
					sx = 352
				elif sx > 1760:
					sx = 1760
				BrownTank.tracked(sx, Main.DISPLAY_HEIGHT + 48, self)


func render() -> void:
	pass
