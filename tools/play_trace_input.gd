# The pad tools/play_trace.gd plays with: a fixed pattern of the tick count,
# so two runs press exactly the same buttons on exactly the same ticks.
extends HumanInput

var t: int = 0
# Fire only, no driving; play_trace moves the jeep itself.
var ghost := false


func _init() -> void:
	super(ButtonMapping.new())


func snap() -> void:
	t += 1
	var phase := t % 900
	_up = not ghost and phase < 700
	_down = not ghost and phase >= 820
	_left = not ghost and (t / 170) % 3 == 0
	_right = not ghost and (t / 170) % 3 == 2
	_shoot = t % 12 < 6
	_fire = t % 70 < 3
	_mouse_left = false
	_mouse_right = false
	_aim_moved = false
	_enter = false
	_escape = false
	_pause_key = false
	_f12 = false
