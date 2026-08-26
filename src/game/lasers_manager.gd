# Port of jackal.LasersManager.
#
# Drives a bank of three laser emitters: outer lamps flash, inner lamps flash,
# a warm-up pause, then a beam. Between shots it moves to the next emitter that
# is actually on screen.
class_name LasersManager
extends GameElement

const STATE_OUTER_FLASHING := 0
const STATE_INNER_FLASHING := 1
const STATE_WARMING_UP := 2
const STATE_LASERING := 3

const BEAM_SPACING := 8.0 * 32
const VERTICAL_SPACE := 16.0 * 32

const OUTER_FLASH_TIME := 16
const INNER_FLASH_TIME := 16
const WARM_UP_TIME := 16
const LASER_TIME := 46

var state: int = STATE_OUTER_FLASHING
var delay: int = OUTER_FLASH_TIME
var beam_index: int = 0
var visibles: Array[bool] = [false, false, false]
var flash: bool
var color_index: int
var laser: Laser


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	layer = 4


func _advance_beam_index() -> void:
	for i in 3:
		visibles[i] = _beam_visible(x + 64 + i * BEAM_SPACING)
	var next_index := beam_index + 1
	if next_index == 3:
		next_index = 0
	if visibles[next_index]:
		beam_index = next_index
		return
	next_index += 1
	if next_index == 3:
		next_index = 0
	if visibles[next_index]:
		beam_index = next_index


func _beam_visible(beam_x: float) -> bool:
	return not (beam_x + 8 < game_mode.camera_x
		or beam_x - 8 > game_mode.camera_x + Main.SCREEN_WIDTH)


func update() -> void:
	if delay > 0:
		delay -= 1
		return

	match state:
		STATE_OUTER_FLASHING:
			state = STATE_INNER_FLASHING
			delay = INNER_FLASH_TIME
		STATE_INNER_FLASHING:
			state = STATE_WARMING_UP
			delay = WARM_UP_TIME
		STATE_WARMING_UP:
			state = STATE_LASERING
			delay = LASER_TIME
			laser = Laser.new(64 + x + BEAM_SPACING * beam_index, y - 828)
		STATE_LASERING:
			state = STATE_OUTER_FLASHING
			delay = OUTER_FLASH_TIME
			laser.do_remove()
			_advance_beam_index()


func check_bounds(max_y: float) -> void:
	if y - 512 > max_y:
		do_remove()


func render() -> void:
	flash = not flash
	color_index += 1
	if color_index == 4:
		color_index = 0

	var X := x + BEAM_SPACING * beam_index

	match state:
		STATE_OUTER_FLASHING:
			if flash:
				var Y := y + 40
				for i in 2:
					main.draw(main.lasers[4], X + 16, Y)
					main.draw(main.lasers[4], X + 96, Y)
					Y -= VERTICAL_SPACE
				Y += 64
				main.draw(main.lasers[4], X + 16, Y)
				main.draw(main.lasers[4], X + 96, Y)
		STATE_INNER_FLASHING:
			if flash:
				var Y := y + 44
				for i in 2:
					main.draw(main.lasers[5], X + 48, Y)
					main.draw(main.lasers[5], X + 68, Y)
					Y -= VERTICAL_SPACE
				Y += 64
				main.draw(main.lasers[5], X + 48, Y)
				main.draw(main.lasers[5], X + 68, Y)
		STATE_LASERING:
			for i in range(1, 13):
				main.draw(main.lasers[color_index], X + 48, y - (i << 5) + 4)
			for i in range(1, 11):
				main.draw(main.lasers[color_index], X + 48, y - (i << 5) - 508)
