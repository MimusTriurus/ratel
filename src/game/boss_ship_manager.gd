# Port of jackal.BossShipManager: opens two on-screen turrets at a time and
# feeds brown tanks in from the bottom until every turret is destroyed.
class_name BossShipManager
extends GameElement

const MAX_TANKS := 5
const TRIGGER_DELAY := 4 * 91

var ready: bool
var brown_tank_delay: int = 45
var ship_guns: Array[BossShipGun] = []
var gun_index: int
var trigger_delay: int = 1
var tanks: int


func init() -> void:
	game_mode.start_boss_camera_pan(self)

	ship_guns = []
	ship_guns.append(BossShipGun.new(36 << 5, 8 << 5, self))
	ship_guns.append(BossShipGun.new(28 << 5, 10 << 5, self))
	ship_guns.append(BossShipGun.new(28 << 5, 6 << 5, self))
	ship_guns.append(BossShipGun.new(22 << 5, 10 << 5, self))
	ship_guns.append(BossShipGun.new(22 << 5, 6 << 5, self))
	ship_guns.append(BossShipGun.new(13 << 5, 8 << 5, self))


func pan_complete() -> void:
	ready = true


func tank_created() -> void:
	tanks += 1


func tank_destroyed() -> void:
	tanks -= 1


func update() -> void:
	if not ready:
		return

	trigger_delay -= 1
	if trigger_delay == 0:
		_trigger_guns()
		trigger_delay = TRIGGER_DELAY

	if not ship_guns.is_empty():
		brown_tank_delay -= 1
		if brown_tank_delay < 0:
			if tanks >= MAX_TANKS:
				brown_tank_delay = 91
			else:
				brown_tank_delay = 10 * 91
				var sx := game_mode.camera_x \
					+ main.random.randi_range(0, Main.SCREEN_WIDTH - 1)
				if sx < 320:
					sx = 320
				elif sx > 1472:
					sx = 1472
				BrownTank.tracked(sx, Main.DISPLAY_HEIGHT + 48, self)


# Walks the turret list from wherever it left off, opening the next two that
# are actually on screen, the second one a beat later.
func _trigger_guns() -> void:
	if ship_guns.is_empty():
		return
	var count := 0
	var i := ship_guns.size() - 1
	while i >= 0 and count < 2:
		if gun_index >= ship_guns.size():
			gun_index = 0
		var gun: BossShipGun = ship_guns[gun_index]
		if gun.is_openable():
			gun.open(23 * count)
			count += 1
		i -= 1
		gun_index += 1


func gun_destroyed(gun: BossShipGun) -> void:
	ship_guns.erase(gun)
	if ship_guns.is_empty():
		game_mode.destroy_all()
		game_mode.mark_stage_completed()


func render() -> void:
	pass
