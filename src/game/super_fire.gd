# Port of jackal.SuperFire.
#
# The super tank's flame column: a spinning charge-up "aster", then a beam that
# grows to full length and finally detaches and travels down the screen. The
# beam is drawn as head, repeated body and tail segments, clipped to length.
class_name SuperFire
extends GameElement

const STATE_ASTER := 0
const STATE_DIAMOND := 1
const STATE_GROWING := 2
const STATE_MOVING := 3

const ASTER_DELAY := 23
const ASTER_SPINES := 5
const ASTER_RADIUS := 128.0
const ASTER_ANGLE := PI
const ASTER_SPACER_ANGLE := 2.0 * PI / ASTER_SPINES

const SPEED := 11.0

static var ASTERS_XYS: Array = []              # [ASTER_DELAY][ASTER_SPINES]
static var ASTER_SCALES: PackedFloat32Array = PackedFloat32Array()

var player: Player
var state: int = STATE_ASTER
var length: float
var flicker_counter: float
var flicker_index: int
var aster_delay: int
var boss_super_tank = null


static func _static_init() -> void:
	ASTER_SCALES.resize(ASTER_DELAY)
	ASTERS_XYS = []
	ASTERS_XYS.resize(ASTER_DELAY)
	for i in ASTER_DELAY:
		ASTER_SCALES[i] = float(i) / float(ASTER_DELAY - 1)
		var radius := (1.0 - ASTER_SCALES[i]) * ASTER_RADIUS
		var angle := ASTER_SCALES[i] * ASTER_ANGLE
		var spines: Array[Vector2] = []
		spines.resize(ASTER_SPINES)
		for j in ASTER_SPINES:
			var ang := angle + ASTER_SPACER_ANGLE * j
			spines[j] = Vector2(radius * cos(ang), radius * sin(ang))
		ASTERS_XYS[i] = spines


func _init(p_x: float, p_y: float, p_boss_super_tank) -> void:
	super()
	x = p_x
	y = p_y
	boss_super_tank = p_boss_super_tank


func init() -> void:
	layer = 5
	player = game_mode.player


func update() -> void:
	match state:
		STATE_ASTER:
			aster_delay += 1
			if aster_delay == ASTER_DELAY:
				state = STATE_DIAMOND
				main.play_sound(main.fire_sound)
		STATE_DIAMOND:
			length += SPEED
			if length >= 128:
				state = STATE_GROWING
		STATE_GROWING:
			length += SPEED
			if length >= 512:
				length = 512
				state = STATE_MOVING
		STATE_MOVING:
			y += SPEED
			if y > game_mode.camera_y + Main.SCREEN_HEIGHT + 32:
				do_remove()

	if state != STATE_ASTER:
		player.attack_rect(x - 40, y + 32, x + 40, y + length - 32)

	if boss_super_tank.remove:
		do_remove()


func render() -> void:
	# The flicker alternates every 2.5 ticks, so it cannot be a plain counter.
	if flicker_counter >= 2.5:
		flicker_counter -= 2.5
	else:
		flicker_index ^= 1
	flicker_counter += 1

	var X := x - 48
	var half_length := length * 0.5
	var sheet: Array = main.super_fires[flicker_index]

	match state:
		STATE_ASTER:
			var spines: Array = ASTERS_XYS[aster_delay]
			for i in ASTER_SPINES:
				main.draw_centered_scaled(main.elephant_guns[4],
					x + spines[i].x, y + spines[i].y,
					ASTER_SCALES[aster_delay], ASTER_SCALES[aster_delay])
		STATE_DIAMOND:
			main.set_clip(X - 1, y, 98, half_length)
			main.draw(sheet[0], X, y)
			main.set_clip(X - 1, y + half_length, 98, half_length)
			main.draw(sheet[2], X, y + length - 64)
			main.clear_clip()
		STATE_GROWING:
			main.draw(sheet[0], X, y)
			main.set_clip(X - 1, y + 64, 98, length)
			for i in range(1 + (int(length - 128) >> 5), -1, -1):
				main.draw(sheet[1], X, y + length - (i << 5) - 64)
			main.clear_clip()
			main.draw(sheet[2], X, y + length - 64)
		_:
			main.draw(sheet[0], X, y)
			for i in 12:
				main.draw(sheet[1], X, y + 64 + (i << 5))
			main.draw(sheet[2], X, y + 448)
