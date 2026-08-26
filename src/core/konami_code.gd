class_name KonamiCode
extends RefCounted

enum Keys { NONE, UP, DOWN, LEFT, RIGHT, GRENADE, GUN }

# Try the following sequence on the title screen :)
const SEQUENCE: Array[Keys] = [
	Keys.UP,
	Keys.UP,
	Keys.DOWN,
	Keys.DOWN,
	Keys.LEFT,
	Keys.RIGHT,
	Keys.LEFT,
	Keys.RIGHT,
	Keys.GUN,
	Keys.GRENADE,
]

var enabled: bool
var key_released: bool
var main: Main
var input: HumanInput
var sequence_index: int

func _init(p_main: Main) -> void:
	main = p_main
	input = p_main.input


func getting_close() -> bool:
	return not enabled and (SEQUENCE[sequence_index] == Keys.GRENADE
		or SEQUENCE[sequence_index] == Keys.GUN)


func update() -> void:
	if not (input.is_down() or input.is_up() or input.is_left() or input.is_right()
			or input.is_shoot() or input.is_fire()):
		key_released = true

	if enabled:
		return

	if not key_released:
		return

	var key := Keys.NONE
	if input.is_up():
		key_released = false
		key = Keys.UP
	elif input.is_down():
		key_released = false
		key = Keys.DOWN
	elif input.is_left():
		key_released = false
		key = Keys.LEFT
	elif input.is_right():
		key_released = false
		key = Keys.RIGHT
	elif input.is_fire():
		key_released = false
		key = Keys.GRENADE
	elif input.is_shoot():
		key_released = false
		key = Keys.GUN

	if key == SEQUENCE[sequence_index]:
		sequence_index += 1
		if sequence_index == SEQUENCE.size():
			main.play_sound_always(main.weapon_upgrade_sound)
			enabled = true
	elif key != Keys.NONE:
		sequence_index = 0
