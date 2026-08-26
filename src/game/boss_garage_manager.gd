# Port of jackal.BossGarageManager.
#
# Cycles through four garages opening whichever is on screen, keeps five guns
# firing, and animates the electric arc across the gate. Destroying all four
# garages kills the arc and reveals the gate that ends the stage.
class_name BossGarageManager
extends GameElement

const LONG_DELAY := 4 * 91
const SHORT_DELAY := 1 * 91
const MAX_TANKS := 5
const SPARK_SPEED := 4.25

var ready: bool
var garages: Array[BossGarage] = []
var open_delay: int = SHORT_DELAY
var garage_index: int
var tanks: int
var garage_count: int = 4
var spark_x: float
var spark_state: int = 0
var sparking: bool = true


func init() -> void:
	game_mode.start_boss_camera_pan(self)

	garages = []
	garages.append(BossGarage.new(14 * 32, 9 * 32, self))
	garages.append(BossGarage.new(20 * 32, 9 * 32, self))
	garages.append(BossGarage.new(46 * 32, 9 * 32, self))
	garages.append(BossGarage.new(52 * 32, 9 * 32, self))

	RotatingGun.make_garage(4.5 * 32, 5 * 32 + 4, self, false)
	RotatingGun.make_garage(9.5 * 32, 5 * 32 + 4, self, false)
	RotatingGun.make_garage(28.5 * 32, 5 * 32 + 4, self, true)
	RotatingGun.make_garage(41.5 * 32, 5 * 32 + 4, self, true)
	RotatingGun.make_garage(60.5 * 32, 5 * 32 + 4, self, false)

	layer = 0


func pan_complete() -> void:
	ready = true


func gate_open() -> void:
	game_mode.destroy_all()
	game_mode.mark_stage_completed()


func tank_created() -> void:
	tanks += 1


func tank_destroyed() -> void:
	tanks -= 1


func garage_destroyed() -> void:
	garage_count -= 1
	if garage_count == 0:
		sparking = false
		Gate.for_garage(32 * 32, 6 * 32, self)


func full() -> bool:
	return tanks >= MAX_TANKS


func update() -> void:
	if not ready:
		return

	open_delay -= 1
	if open_delay == 0:
		var boss_garage: BossGarage = null
		while true:
			var b: BossGarage = garages[garage_index]
			garage_index += 1
			if not b.remove and b.x + 128 > game_mode.camera_x \
					and b.x < game_mode.camera_x + Main.DISPLAY_WIDTH:
				boss_garage = b
				break
			elif garage_index == 4:
				break
		if boss_garage != null:
			boss_garage.open()
		if garage_index == 4:
			garage_index = 0
			open_delay = LONG_DELAY
		else:
			open_delay = SHORT_DELAY

	if sparking:
		spark_x += SPARK_SPEED
		# Each stage of the arc lasts 32 pixels of travel.
		if spark_state < 6:
			if spark_x > 32 * (spark_state + 1):
				spark_state += 1
		elif spark_x > 224:
			spark_state = 0
			spark_x = 0


func render() -> void:
	if not sparking:
		return

	match spark_state:
		0:
			main.set_clip(992, 192, 256, 160)
			main.draw(main.sparks[0][0], 960 + spark_x, 216)
			main.draw(main.sparks[0][0], 960 + spark_x, 280)
			main.draw(main.sparks[1][0], 1248 - spark_x, 216)
			main.draw(main.sparks[1][0], 1248 - spark_x, 280)
			main.clear_clip()
		1:
			main.set_clip(992, 192, 256, 160)
			main.draw(main.sparks[0][1], 928 + spark_x, 216)
			main.draw(main.sparks[0][1], 928 + spark_x, 280)
			main.draw(main.sparks[1][1], 1248 - spark_x, 216)
			main.draw(main.sparks[1][1], 1248 - spark_x, 280)
			main.clear_clip()
		2:
			main.set_clip(992, 192, 256, 160)
			main.draw(main.sparks[0][2], 896 + spark_x, 216)
			main.draw(main.sparks[0][2], 896 + spark_x, 280)
			main.draw(main.sparks[1][2], 1248 - spark_x, 216)
			main.draw(main.sparks[1][2], 1248 - spark_x, 280)
			main.clear_clip()
		3:
			main.set_clip(992, 192, 256, 160)
			main.draw(main.sparks[0][3], 896 + spark_x, 216)
			main.draw(main.sparks[0][3], 896 + spark_x, 280)
			main.draw(main.sparks[1][3], 1248 - spark_x, 216)
			main.draw(main.sparks[1][3], 1248 - spark_x, 280)
			main.draw(main.sparks[0][6], 1088, 203)
			main.draw(main.sparks[0][6], 1088, 267)
			main.clear_clip()
		4:
			main.set_clip(992, 192, 128, 160)
			main.draw(main.sparks[0][4], 896 + spark_x, 216)
			main.draw(main.sparks[0][4], 896 + spark_x, 280)
			main.set_clip(1120, 192, 128, 160)
			main.draw(main.sparks[1][4], 1248 - spark_x, 216)
			main.draw(main.sparks[1][4], 1248 - spark_x, 280)
			main.clear_clip()
		5:
			main.set_clip(992, 192, 128, 160)
			main.draw(main.sparks[0][5], 896 + spark_x, 216)
			main.draw(main.sparks[0][5], 896 + spark_x, 280)
			main.set_clip(1120, 192, 128, 160)
			main.draw(main.sparks[1][5], 1280 - spark_x, 216)
			main.draw(main.sparks[1][5], 1280 - spark_x, 280)
			main.clear_clip()
		6:
			main.set_clip(992, 192, 128, 160)
			main.draw(main.sparks[1][5], 896 + spark_x, 216)
			main.draw(main.sparks[1][5], 896 + spark_x, 280)
			main.set_clip(1120, 192, 128, 160)
			main.draw(main.sparks[0][5], 1280 - spark_x, 216)
			main.draw(main.sparks[0][5], 1280 - spark_x, 280)
			main.clear_clip()
