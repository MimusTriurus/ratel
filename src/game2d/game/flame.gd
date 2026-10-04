# Port of jackal.Flame: the pool of fire left where a flamethrower jet lands.
class_name Flame
extends GameElement

const TIME_TO_LIVE := 1 * 91

static var ALPHAS: PackedFloat32Array = PackedFloat32Array()

var sprite_counter: int
var sprite_index: int
var delay: int = TIME_TO_LIVE


static func _static_init() -> void:
	ALPHAS.resize(TIME_TO_LIVE)
	for i in TIME_TO_LIVE:
		ALPHAS[i] = sqrt(i / float(TIME_TO_LIVE))


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	layer = 0


func update() -> void:
	delay -= 1
	if delay == 0:
		do_remove()


func render() -> void:
	sprite_counter += 1
	if sprite_counter == 8:
		sprite_counter = 0
		sprite_index ^= 1
	main.draw_centered_alpha(main.fires[sprite_index][2], x, y, ALPHAS[delay])
