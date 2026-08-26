# jackal.HumanInput. Level-triggered states are sampled once per logic tick by
# snap(); edge-triggered states are derived from the previous snap, which is
# also what makes clear_key_pressed_record() work.
class_name HumanInput
extends RefCounted

const AXIS_DEADZONE := 0.5

# Fallback gun keys, matching the original's Z / Y / W / K set.
const GUN_FALLBACK: Array[Key] = [KEY_Z, KEY_Y, KEY_W, KEY_K]

var button_mapping: ButtonMapping

var _up: bool
var _down: bool
var _left: bool
var _right: bool
var _fire: bool
var _shoot: bool

var _enter: bool
var _f12: bool
var _escape: bool
var _pause_key: bool

var _prev_enter: bool
var _prev_f12: bool
var _prev_escape: bool
var _prev_pause_key: bool

func _init(p_button_mapping: ButtonMapping) -> void:
	button_mapping = p_button_mapping


func snap() -> void:
	var bm := button_mapping

	_up = Input.is_key_pressed(bm.key_up)
	_down = Input.is_key_pressed(bm.key_down)
	_left = Input.is_key_pressed(bm.key_left)
	_right = Input.is_key_pressed(bm.key_right)
	_fire = Input.is_key_pressed(bm.key_grenade)

	if bm.gun_key_mapped:
		_shoot = Input.is_key_pressed(bm.key_gun)
	else:
		_shoot = false
		for k in GUN_FALLBACK:
			if Input.is_key_pressed(k):
				_shoot = true
				break

	if bm.controller:
		var d := bm.controller_index
		_up = _up or Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP) \
			or Input.get_joy_axis(d, JOY_AXIS_LEFT_Y) < -AXIS_DEADZONE
		_down = _down or Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN) \
			or Input.get_joy_axis(d, JOY_AXIS_LEFT_Y) > AXIS_DEADZONE
		_left = _left or Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT) \
			or Input.get_joy_axis(d, JOY_AXIS_LEFT_X) < -AXIS_DEADZONE
		_right = _right or Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT) \
			or Input.get_joy_axis(d, JOY_AXIS_LEFT_X) > AXIS_DEADZONE
		_fire = _fire or Input.is_joy_button_pressed(d, bm.controller_grenade)
		_shoot = _shoot or Input.is_joy_button_pressed(d, bm.controller_gun)

	_prev_enter = _enter
	_prev_f12 = _f12
	_prev_escape = _escape
	_prev_pause_key = _pause_key

	_enter = Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER)
	_f12 = Input.is_key_pressed(KEY_F12)
	_escape = Input.is_key_pressed(KEY_ESCAPE)
	_pause_key = Input.is_key_pressed(KEY_P) or _enter


func reset() -> void:
	pass


func is_up() -> bool:
	return _up


func is_down() -> bool:
	return _down


func is_left() -> bool:
	return _left


func is_right() -> bool:
	return _right


func is_fire() -> bool:
	return _fire


func is_shoot() -> bool:
	return _shoot


func is_enter() -> bool:
	return _enter and not _prev_enter


func is_f12() -> bool:
	return _f12 and not _prev_f12


func is_escape() -> bool:
	return _escape and not _prev_escape


func is_pause() -> bool:
	return _pause_key and not _prev_pause_key


# Slick's Input.clearKeyPressedRecord(): swallow edges that are already down.
func clear_key_pressed_record() -> void:
	_prev_enter = _enter
	_prev_f12 = _f12
	_prev_escape = _escape
	_prev_pause_key = _pause_key


func update() -> bool:
	return true
