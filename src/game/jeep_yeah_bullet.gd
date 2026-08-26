# Port of jackal.JeepYeahBullet: a shell casing arcing out of the cutscene gun.
class_name JeepYeahBullet
extends RefCounted

const VX0 := -2.0
const VY0 := -5.0
const G := 0.25
const ANGLE_SPEED := -5.0
const SCALE_SPEED := 0.015

var x: float = 308
var y: float = 408
var vx: float = VX0
var vy: float = VY0
var angle: float = -50
var remove: bool
var scale: float = 1


func update() -> void:
	angle += ANGLE_SPEED
	vy += G
	x += vx
	y += vy

	scale -= SCALE_SPEED
	if scale <= 0:
		remove = true


func render(main: Main) -> void:
	main.draw_rotated_offset_scaled(main.jeep_yeah_bullet, x, y, -10, -2,
		angle, scale)
