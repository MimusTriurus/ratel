# jackal.HumanInput. Level-triggered states are sampled once per logic tick by
# snap(); edge-triggered states are derived from the previous snap, which is
# also what makes clear_key_pressed_record() work.
#
# Beyond the original: the arrow keys always work as a second set of direction
# keys (so menus stay navigable whatever movement is bound to), and the mouse
# drives aiming and both weapons. Mouse buttons are deliberately kept out of
# is_fire()/is_shoot() — those feed the menus, the title screen and the Konami
# code, which must not react to a click. Player reads is_gun()/is_grenade().
class_name HumanInput
extends RefCounted

const AXIS_DEADZONE := 0.5

# Fallback gun keys, matching the original's Z / Y / W / K set. W is only a gun
# key while nothing else claims it — the default movement keys are WASD.
const GUN_FALLBACK: Array[Key] = [KEY_Z, KEY_Y, KEY_W, KEY_K]

# Second, always-live set of direction keys.
const ARROWS: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]

# The aim angle is only recomputed once the cursor is this far from the jeep,
# so that a click right on top of it does not snap the turret somewhere random.
const AIM_DEADZONE := 24.0

var button_mapping: ButtonMapping

var _up: bool
var _down: bool
var _left: bool
var _right: bool
var _fire: bool
var _shoot: bool

var _mouse_left: bool
var _mouse_right: bool
var _aim_pos: Vector2
var _aim_seen: bool
var _aim_moved: bool

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

	_up = Input.is_key_pressed(bm.key_up) or Input.is_key_pressed(ARROWS[0])
	_down = Input.is_key_pressed(bm.key_down) or Input.is_key_pressed(ARROWS[1])
	_left = Input.is_key_pressed(bm.key_left) or Input.is_key_pressed(ARROWS[2])
	_right = Input.is_key_pressed(bm.key_right) or Input.is_key_pressed(ARROWS[3])
	_fire = Input.is_key_pressed(bm.key_grenade)

	_snap_mouse()

	if bm.gun_key_mapped:
		_shoot = Input.is_key_pressed(bm.key_gun)
	else:
		_shoot = false
		for k in GUN_FALLBACK:
			# W is in the original's fallback set and is also the default "up",
			# so a fallback key that a direction claims is not a gun key.
			if k == bm.key_up or k == bm.key_down or k == bm.key_left \
					or k == bm.key_right or k == bm.key_grenade:
				continue
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


# Sampled once per logic tick like everything else, so the aim angle a shot
# uses is the one the cursor had on that tick.
func _snap_mouse() -> void:
	if not button_mapping.mouse_aim or Main.main == null:
		_mouse_left = false
		_mouse_right = false
		_aim_moved = false
		return

	var m := Main.main.get_local_mouse_position()
	if not _aim_seen:
		_aim_seen = true
	elif m != _aim_pos:
		# Aiming only takes over once the cursor has actually moved, so a jeep
		# does not start the stage shooting at wherever the pointer was parked.
		_aim_moved = true
	_aim_pos = m

	_mouse_left = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_mouse_right = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func reset() -> void:
	pass


# True once the cursor has moved and mouse aiming is on.
func is_aiming() -> bool:
	return _aim_moved


# Cursor position in display space; add the camera offset for world space.
func aim_position() -> Vector2:
	return _aim_pos


# Machine gun: the mapped gun key, the pad button, or LMB.
func is_gun() -> bool:
	return _shoot or _mouse_left


# Grenade / missile: the mapped grenade key, the pad button, or RMB.
func is_grenade() -> bool:
	return _fire or _mouse_right


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
