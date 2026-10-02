# Port of jackal.IntroPlayer: the stand-in jeep that reverses out of the
# Chinook before control is handed to the real Player.
#
# Two players unload two (not in the original, which had one jeep). The second
# follows the first down the same ramp, then cuts the diagonal short and backs
# straight down for the rest of the way, so that it ends up beside the first
# where GameMode.place_players will put it rather than on top of it.
class_name IntroPlayer
extends GameElement

const STATE_DIAGONAL := 0
const STATE_REVERSE := 1
const STATE_PAUSED := 2
const STATE_DOWN := 3

const DIAGONAL_TIME := 75
const REVERSE_TIME := 11

const FINAL_X := 328.5
const FINAL_Y := 11074.0

var angle: float = -45
var state: int = STATE_DIAGONAL
var delay: int = DIAGONAL_TIME
var chinook: Chinook
var second: bool
var final_x: float = FINAL_X
# The second jeep's ticks of backing straight down, taken off its diagonal.
var down_time: int


func _init(p_x: float, p_y: float, p_chinook: Chinook, p_second: bool = false) -> void:
	super()
	x = p_x
	y = p_y
	chinook = p_chinook
	second = p_second
	if second:
		final_x = game_mode.second_spawn_x(FINAL_X, FINAL_Y)
		var shift := roundi((final_x - FINAL_X) / Player.SPEED)
		if shift > 0 and shift < DIAGONAL_TIME:
			delay = DIAGONAL_TIME - shift
			down_time = shift


func init() -> void:
	layer = 3


func update() -> void:
	match state:
		STATE_DIAGONAL:
			x -= Player.SPEED
			y += Player.SPEED
			delay -= 1
			if delay == 0:
				if down_time > 0:
					state = STATE_DOWN
					delay = down_time
				else:
					state = STATE_REVERSE
					delay = REVERSE_TIME
		STATE_DOWN:
			y += Player.SPEED
			angle = maxf(angle - Player.ANGLE_VELOCITY, -90)
			delay -= 1
			if delay == 0:
				state = STATE_REVERSE
				delay = REVERSE_TIME
		STATE_REVERSE:
			if angle > -90:
				angle -= Player.ANGLE_VELOCITY
			else:
				angle = -90
			delay -= 1
			if delay == 0:
				state = STATE_PAUSED
				x = final_x
				y = FINAL_Y
				chinook.unload_completed()


func render() -> void:
	main.draw_vehicle(main.players_blue if second else main.players[0],
		x, y + Player.RUMBLE[0], angle)
