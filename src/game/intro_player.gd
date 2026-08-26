# Port of jackal.IntroPlayer: the stand-in jeep that reverses out of the
# Chinook before control is handed to the real Player.
class_name IntroPlayer
extends GameElement

const STATE_DIAGONAL := 0
const STATE_REVERSE := 1
const STATE_PAUSED := 2

const DIAGONAL_TIME := 75
const REVERSE_TIME := 11

const FINAL_X := 328.5
const FINAL_Y := 11074.0

var angle: float = -45
var state: int = STATE_DIAGONAL
var delay: int = DIAGONAL_TIME
var chinook: Chinook


func _init(p_x: float, p_y: float, p_chinook: Chinook) -> void:
	super()
	x = p_x
	y = p_y
	chinook = p_chinook


func init() -> void:
	layer = 3


func update() -> void:
	match state:
		STATE_DIAGONAL:
			x -= Player.SPEED
			y += Player.SPEED
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
				x = FINAL_X
				y = FINAL_Y
				chinook.unload_completed()


func render() -> void:
	main.draw_vehicle(main.players[0], x, y + Player.RUMBLE[0], angle)
