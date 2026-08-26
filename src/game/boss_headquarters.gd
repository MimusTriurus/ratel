# Port of jackal.BossHeadquarters.
#
# Takes twelve grenades, then plays out a long scripted destruction: the music
# stops, everything else on screen is wiped, explosions rain over the base, and
# finally the building collapses into TileDebris and the super tank rolls in.
class_name BossHeadquarters
extends Enemy

const STATE_FLASHING := 0
const STATE_EXPLOSIONS := 1
const STATE_DEBRIS := 2

const FLASH_DELAY := 68
const FLASH_DURATION := 12

const HITS := 12

const EXPLODE_DELAY := 16
const EXPLODE_TIME := 5 * 91

var flashing: bool
var flash_delay: int = FLASH_DELAY
var flash_index: int = -1
var state: int = STATE_FLASHING
var hits: int
var explode_delay: int
var explode_time: int = EXPLODE_TIME
var boss_headquarters_manager = null
var player: Player


func _init(p_manager) -> void:
	super()
	x = 896
	y = 96
	boss_headquarters_manager = p_manager


func init() -> void:
	super.init()

	player = game_mode.player

	layer = 0

	hit_x1 = 8
	hit_y1 = 8
	hit_x2 = 248
	hit_y2 = 152

	points = 5000


func _start_exploding() -> void:
	state = STATE_EXPLOSIONS
	main.stop_song()
	explode_delay = 1
	boss_headquarters_manager.do_remove()
	game_mode.destroy_all_except(self)
	main.play_sound_always(main.headquarters_explodes_sound)


func _start_debris() -> void:
	state = STATE_DEBRIS
	main.request_song(main.super_tank_song)
	BossSuperTank.new(game_mode.player.x - 210, 32)
	var group: Array = game_mode.groups[0]
	for i in range(group.size() - 1, -1, -1):
		var g: Array = group[i]
		TileDebris.new(g[0], g[1], g[2], g[3])


func update() -> void:
	if state == STATE_EXPLOSIONS:
		explode_delay -= 1
		if explode_delay == 0:
			explode_delay = EXPLODE_DELAY
			for i in 2:
				var e := Explosion.new(
					game_mode.camera_x + main.random.randi_range(0, 1279) - 128,
					224 + main.random.randi_range(0, 223))
				e.set_damages_enemies(false)
			var e2 := Explosion.new(896 + main.random.randi_range(0, 255),
				96 + main.random.randi_range(0, 415))
			e2.set_damages_enemies(false)
		explode_time -= 1
		if explode_time == 0:
			_start_debris()
			do_remove()
	else:
		# Without missiles the player cannot reach as far, so extend the box.
		hit_y2 = 152 if main.has_missiles else 192


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if state != STATE_FLASHING or attack_source != AttackSource.PLAYER_WEAPON \
			or not hit_rect(x1, y1, x2, y2):
		return false

	hits += 1
	if hits == HITS:
		_start_exploding()
	else:
		main.play_hit_explode_sound()
		# A grid of delayed explosions climbs the facade, skipping the corners.
		for i in 7:
			var Y := y + 160 - (i << 5)
			for j in 4:
				if (j == 0 or j == 3) and (i == 0 or i == 6):
					continue
				Explosion.delayed(
					x + (j << 6) + 12 + main.random.randi_range(0, 31),
					Y + main.random.randi_range(0, 7), true, (i + 1) * 4, 0.5)
	return true


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	return hit_rect(x1, y1, x2, y2)


func render() -> void:
	if state != STATE_FLASHING:
		return

	flash_delay -= 1
	if flash_delay == 0:
		if flashing:
			flashing = false
			flash_delay = FLASH_DELAY
		else:
			flashing = true
			flash_delay = FLASH_DURATION
	if not flashing:
		return

	flash_index += 1
	if flash_index == 2:
		flash_index = -1
	else:
		main.draw(main.headquarters_lights[flash_index], 932, 188)
		main.draw(main.headquarters_lights[flash_index], 996, 220)
		main.draw(main.headquarters_lights[flash_index], 1028, 220)
		main.draw(main.headquarters_lights[flash_index], 1092, 188)
