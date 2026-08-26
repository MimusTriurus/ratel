# Port of jackal.JeepYeahFireRight: the muzzle flash on the cutscene jeep. It grows out
# of the barrel, detaches for a tick, then shrinks away along the same line.
class_name JeepYeahFireRight
extends RefCounted

const STATE_GROWING := 0
const STATE_MOVING := 1
const STATE_SHRINKING := 2
const STATE_PAUSED := 3

const SPEED := 20.0

const ANGLE := -30.0
const RX := cos(deg_to_rad(ANGLE))
const RY := sin(deg_to_rad(ANGLE))
const VX := SPEED * RX
const VY := SPEED * RY

const MOVE_TIME := 1
const SHRINK_STEPS := int(75 / SPEED)
const PAUSE_TIME := 3

const I_SHRINK_STEPS := 1.0 / SHRINK_STEPS

var scale: float
var state: int
var x: float
var y: float
var delay: int



func update() -> void:
	match state:
		STATE_GROWING:
			x += SPEED
			scale = x / 75
			if scale >= 1:
				state = STATE_MOVING
				delay = MOVE_TIME
				x = 768
				y = 437
		STATE_MOVING:
			x += VX
			y += VY
			delay -= 1
			if delay == 0:
				state = STATE_SHRINKING
				delay = SHRINK_STEPS
		STATE_SHRINKING:
			x += VX
			y += VY
			scale = I_SHRINK_STEPS * delay
			delay -= 1
			if delay == 0:
				state = STATE_PAUSED
				delay = PAUSE_TIME
		STATE_PAUSED:
			delay -= 1
			if delay == 0:
				state = STATE_GROWING
				x = 0
				scale = 0


func render(main: Main) -> void:
	match state:
		STATE_GROWING:
			main.draw_rotated_scaled_xy(main.gun_fires[0],
				768, 437, 0, -18, ANGLE, scale, 1)
		STATE_MOVING:
			main.draw_rotated_offset(main.gun_fires[0], x, y, 0, -18, ANGLE)
		STATE_SHRINKING:
			main.draw_rotated_scaled_xy(main.gun_fires[0], x, y, 0, -18,
				ANGLE, scale, 1)
