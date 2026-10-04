# Port of jackal.LandingPort: the rescue helipad, with red and blue lamps
# pulsing half a period apart.
class_name LandingPort
extends GameElement

const TYPE_LEFT := 0
const TYPE_RIGHT := 1
const TYPE_CIRCLE := 2

const CIRCLE_LIGHTS: Array[Vector2i] = [
	Vector2i(392, 112),
	Vector2i(328, 48),
	Vector2i(264, 16),
	Vector2i(168, 16),
	Vector2i(104, 48),
	Vector2i(40, 112),
	Vector2i(8, 208),
	Vector2i(8, 272),
	Vector2i(40, 368),
	Vector2i(104, 432),
	Vector2i(168, 464),
	Vector2i(264, 464),
	Vector2i(328, 432),
	Vector2i(392, 368),
]

static var ALPHAS: PackedFloat32Array = PackedFloat32Array()

var type: int
var red_index: int = 0
var blue_index: int = 91


static func _static_init() -> void:
	ALPHAS.resize(182)
	for i in 182:
		ALPHAS[i] = 0.5 + sin(PI * i / 91.0) / 2.0


func _init(p_x: float, p_y: float, p_type: int) -> void:
	super()
	x = p_x
	y = p_y
	type = p_type

	match p_type:
		TYPE_LEFT:
			FriendlyHelicopter.new(p_x + 320, p_y + 192, false, true)
		TYPE_RIGHT:
			FriendlyHelicopter.new(p_x + 192, p_y + 192, false, false)
		TYPE_CIRCLE:
			FriendlyHelicopter.new(p_x + 224, p_y + 256, false, false)


func init() -> void:
	layer = 0


func update() -> void:
	red_index += 1
	if red_index == 182:
		red_index = 0
	blue_index += 1
	if blue_index == 182:
		blue_index = 0


func _draw_red(X: float, Y: float) -> void:
	main.draw(main.lamps[3], X, Y)
	main.draw(main.lamps[2], X, Y, ALPHAS[red_index])


func _draw_blue(X: float, Y: float) -> void:
	main.draw(main.lamps[1], X, Y)
	main.draw(main.lamps[0], X, Y, ALPHAS[blue_index])


func render() -> void:
	match type:
		TYPE_LEFT, TYPE_RIGHT:
			var x0: float = x + (136 if type == TYPE_LEFT else 40)
			for i in 6:
				var X := x0 + (i << 6)
				var Y := y + 16
				if (i & 1) == 0:
					_draw_red(X, Y)
					_draw_red(X, Y + 320)
				else:
					_draw_blue(X, Y)
					_draw_blue(X, Y + 320)
			var side_x: float = x + (488 if type == TYPE_LEFT else 8)
			var red_parity: int = 0 if type == TYPE_LEFT else 1
			for i in 3:
				var Y := y + 80 + i * 96
				if (i & 1) == red_parity:
					_draw_red(side_x, Y)
				else:
					_draw_blue(side_x, Y)
		TYPE_CIRCLE:
			var blue := true
			for i in range(CIRCLE_LIGHTS.size() - 1, -1, -1):
				var X := x + CIRCLE_LIGHTS[i].x
				var Y := y + CIRCLE_LIGHTS[i].y
				if blue:
					_draw_blue(X, Y)
				else:
					_draw_red(X, Y)
				blue = not blue
