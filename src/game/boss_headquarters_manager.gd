# Port of jackal.BossHeadquartersManager: sets up the final base fight and
# keeps a steady supply of brown tanks coming up from the bottom.
class_name BossHeadquartersManager
extends GameElement

const MAX_TANKS := 5
const TANK_SPAWN_DELAY := 5 * 91

var ready: bool
var created_enemy_helicopter: bool
var tanks: int
var tank_spawn_delay: int = TANK_SPAWN_DELAY


func init() -> void:
	game_mode.start_boss_camera_pan(self)

	BossHeadquarters.new(self)
	ElephantGun.new(792, 140, true)
	ElephantGun.new(1160, 140, false)


func pan_complete() -> void:
	ready = true


func tank_created() -> void:
	tanks += 1


func tank_destroyed() -> void:
	tanks -= 1


func update() -> void:
	if not ready:
		return

	if not created_enemy_helicopter:
		created_enemy_helicopter = true
		EnemyHelicopter.new(true)

	tank_spawn_delay -= 1
	if tank_spawn_delay == 0:
		if tanks == MAX_TANKS:
			tank_spawn_delay = 45
		else:
			tank_spawn_delay = TANK_SPAWN_DELAY
			var tank := BrownTank.tracked(
				256 + main.random.randi_range(0, 1535),
				game_mode.camera_y + Main.DISPLAY_HEIGHT + 48, self)
			tank.display_angle = 270
			tank.target_angle = 270


func render() -> void:
	pass
