# Port of jackal.JeepYeahExplosion: the same growing explosion as in gameplay,
# but standalone so it can run inside a cutscene with no GameMode.
class_name JeepYeahExplosion
extends RefCounted

const GROW_RATE := 1.03

var size: float = 32
var sprite_index: int
var scale: float
var tiny: bool
var delay: int
var alpha: float = 1.0
var x: float
var y: float
var remove: bool


func _init(p_x: float, p_y: float) -> void:
	x = p_x
	y = p_y


func set_alpha(p_alpha: float) -> void:
	alpha = p_alpha


func set_tiny(p_tiny: bool) -> void:
	tiny = p_tiny


func set_delayed(p_delay: int) -> void:
	delay = p_delay


func update() -> void:
	if delay > 0:
		delay -= 1
		if delay != 0:
			return

	size *= GROW_RATE

	if size >= 80:
		sprite_index = 2
		scale = size / 128.0
	elif size >= 56:
		sprite_index = 1
		scale = size / 56.0
	else:
		sprite_index = 0
		scale = size / 32.0

	if (tiny and size > 68) or size > 128:
		remove = true


func render(main: Main) -> void:
	main.draw_scaled(main.explosions[sprite_index], x, y, scale, alpha)
