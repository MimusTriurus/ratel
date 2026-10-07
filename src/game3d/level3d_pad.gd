# Gamepads in the 3D preview: whose a pad is, what a binding is and what it
# is called on the pad in hand, the sticks with their dead zone, the
# triggers as a throttle, a menu's
# moves and picks from a pad's events, and the rumble. The stage reads the
# pads as it reads the keys, held, once a tick (level3d_preview.gd, _drive,
# _aim, _fire, _use_device); the title, the shop, the game over and the
# Escape menu go by their events.
#
# Not the 2D game's pad (ButtonMapping.controller, HumanInput), which the
# second player's mapping used to bring with it here: the preview turns that
# off (_mapping_2) and has its own, in its settings (Level3DSettings.pad*),
# so that one pad is not two players' at once.
#
# Whose: with one player every pad is his, so whichever the system lists --
# Steam Input's virtual one, the pad itself or both -- drives. With two, the
# first two pads are a player's each, in the order they were connected; one
# pad alone is Level3DSettings.pad_single's, by default the second player's,
# the first keeping the keyboard and the mouse, which aim better.
class_name Level3DPad
extends RefCounted

# A binding (Level3DSettings.pad_buttons) is a JoyButton, or a trigger as
# TRIGGER + its axis: a trigger is an axis, held past TRIGGER_DOWN.
const TRIGGER := 100
const TRIGGER_LEFT := TRIGGER + JOY_AXIS_TRIGGER_LEFT
const TRIGGER_RIGHT := TRIGGER + JOY_AXIS_TRIGGER_RIGHT
const TRIGGER_DOWN := 0.5
# The sticks' dead zone, radial, and the rest of the way rescaled to 0..1, so
# that a stick just past it drives slowly rather than at a third.
const DEADZONE := 0.25
# The triggers' dead zone as a throttle, a resting trigger reading a little
# off 0 on some pads.
const TRIGGER_DEADZONE := 0.05
# A stick tilted this far is one of the eight directions, for the classic
# driving's keys; within sin(22.5 deg) of an axis it is not that axis's.
const DIGITAL := 0.4
const DIAGONAL := 0.383
# A menu's move by a stick: tilted past NAV_DOWN it moves once, and again only
# once it has come back under NAV_UP.
const NAV_DOWN := 0.6
const NAV_UP := 0.3

enum Names { AUTO, PLAYSTATION, XBOX }

# The aim assist's strengths (level3d_preview.gd, _assist): the cone about
# the stick's bearing an enemy is pulled from, degrees; the share of it, from
# the middle, where the reticle goes all the way on to the enemy; and how far
# it goes on to one at the cone's edge... up to there, 0 to 1.
enum Assist { OFF, LIGHT, NORMAL, STRONG }
const ASSISTS := [
	{},
	{"cone": 8.0, "inner": 0.0, "pull": 0.6},
	{"cone": 12.0, "inner": 0.35, "pull": 1.0},
	{"cone": 18.0, "inner": 0.5, "pull": 1.0},
]

static var settings: Level3DSettings

# The stick axes as a menu's moves last left them, device * 16 + axis -> -1,
# 0 or 1 (nav).
static var _nav_held := {}


# A and B as the Godot controls' accept and cancel, which in 4.7 are the
# keyboard's alone -- the Escape menu is Godot's controls. Once.
static func install() -> void:
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var event := InputEventJoypadButton.new()
		event.button_index = pair[1]
		event.device = -1
		if not InputMap.action_has_event(pair[0], event):
			InputMap.action_add_event(pair[0], event)


static func connected() -> Array[int]:
	var pads: Array[int] = []
	pads.assign(Input.get_connected_joypads())
	pads.sort()
	return pads


# The pads player `player` (0 or 1) drives with, in a game of `players`.
static func devices(player: int, players: int) -> Array[int]:
	var mine: Array[int] = []
	if settings != null and not settings.pad:
		return mine
	var pads := connected()
	if players < 2:
		return pads if player == 0 else mine
	if pads.size() >= 2:
		if player < 2:
			mine.append(pads[player])
		return mine
	var single := settings.pad_single if settings != null else 1
	return pads if player == single else mine


# The player a pad is, -1 for none.
static func player_of(device: int, players: int) -> int:
	for player in players:
		if devices(player, players).has(device):
			return player
	return -1


# Whether `binding` is held on any of `pads`.
static func held(pads: Array[int], binding: int) -> bool:
	for d in pads:
		if binding >= TRIGGER:
			if Input.get_joy_axis(d, binding - TRIGGER) > TRIGGER_DOWN:
				return true
		elif Input.is_joy_button_pressed(d, binding):
			return true
	return false


# The left stick, out of its dead zone, or the d-pad, which wins: the
# strongest of `pads`'. y down, as the screen's.
static func left(pads: Array[int]) -> Vector2:
	var best := Vector2.ZERO
	for d in pads:
		var dpad := Vector2(
				float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT)),
				float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP)))
		var v := dpad.normalized() if dpad != Vector2.ZERO \
				else _stick(d, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
		if v.length() > best.length():
			best = v
	return best


static func right(pads: Array[int]) -> Vector2:
	var best := Vector2.ZERO
	for d in pads:
		var v := _stick(d, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
		if v.length() > best.length():
			best = v
	return best


static func _stick(device: int, x: JoyAxis, y: JoyAxis) -> Vector2:
	var v := Vector2(Input.get_joy_axis(device, x), Input.get_joy_axis(device, y))
	var length := v.length()
	if length <= DEADZONE:
		return Vector2.ZERO
	return v / length * minf((length - DEADZONE) / (1.0 - DEADZONE), 1.0)


# A stick as the eight directions' keys: up, down, left, right.
static func digital(v: Vector2) -> Array[bool]:
	var length := v.length()
	if length < DIGITAL:
		return [false, false, false, false]
	var k := length * DIAGONAL
	return [v.y < -k, v.y > k, v.x < -k, v.x > k]


# Driving free, the racing way: R2 the throttle, L2 the brake and then
# reverse, -1 to 1, the strongest of `pads`'.
static func throttle(pads: Array[int]) -> float:
	var best := 0.0
	for d in pads:
		var v := _trigger(d, JOY_AXIS_TRIGGER_RIGHT) - _trigger(d, JOY_AXIS_TRIGGER_LEFT)
		if absf(v) > absf(best):
			best = v
	return best


static func _trigger(device: int, axis: JoyAxis) -> float:
	var v := Input.get_joy_axis(device, axis)
	return 0.0 if v <= TRIGGER_DEADZONE else minf((v - TRIGGER_DEADZONE) / (1.0 - TRIGGER_DEADZONE), 1.0)


# Whether anything of `pads` is in use: a stick out of its dead zone, the
# d-pad, a trigger, or one of the bindings -- which hands the player's aim
# and the hints over to the pad (Crew.pad).
static func touched(pads: Array[int], bindings: Array) -> bool:
	if pads.is_empty():
		return false
	if left(pads) != Vector2.ZERO or right(pads) != Vector2.ZERO or throttle(pads) != 0.0:
		return true
	for b in bindings:
		if held(pads, b):
			return true
	return false


# A menu's move from a pad's event: the d-pad, or the left stick tipped over.
# Stateful for the stick, so each event is to be asked once.
static func nav(event: InputEvent) -> Vector2i:
	var button := event as InputEventJoypadButton
	if button != null:
		if not button.pressed:
			return Vector2i.ZERO
		match button.button_index:
			JOY_BUTTON_DPAD_UP: return Vector2i.UP
			JOY_BUTTON_DPAD_DOWN: return Vector2i.DOWN
			JOY_BUTTON_DPAD_LEFT: return Vector2i.LEFT
			JOY_BUTTON_DPAD_RIGHT: return Vector2i.RIGHT
		return Vector2i.ZERO
	var motion := event as InputEventJoypadMotion
	if motion == null or motion.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		return Vector2i.ZERO
	var key := motion.device * 16 + motion.axis
	var was: int = _nav_held.get(key, 0)
	var value := motion.axis_value
	var now := int(signf(value)) if absf(value) > NAV_DOWN else (was if absf(value) > NAV_UP else 0)
	_nav_held[key] = now
	if now == 0 or now == was:
		return Vector2i.ZERO
	return Vector2i(now, 0) if motion.axis == JOY_AXIS_LEFT_X else Vector2i(0, now)


# The direction the d-pad or the left stick is held in, of `pads`, as a
# menu's move: the stick past NAV_DOWN, along its stronger axis.
static func held_dir(pads: Array[int]) -> Vector2i:
	var v := Vector2.ZERO
	for d in pads:
		var dpad := Vector2(
				float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT)),
				float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP)))
		if dpad != Vector2.ZERO:
			v = dpad
			break
		var stick := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if stick.length() > NAV_DOWN and stick.length() > v.length():
			v = stick
	if v == Vector2.ZERO:
		return Vector2i.ZERO
	if absf(v.y) >= absf(v.x):
		return Vector2i(0, int(signf(v.y)))
	return Vector2i(int(signf(v.x)), 0)


# A direction held moves again and again, as a held key's echo does: after
# DELAY, every EVERY. The first move is the press's own (nav), so tick only
# says when to move again. One for each cursor.
class Repeat:
	const DELAY := 0.35
	const EVERY := 0.08

	var _dir := Vector2i.ZERO
	var _held := 0.0
	var _next := DELAY

	# `dir` the direction held this frame (held_dir); the move to make again
	# now, or ZERO.
	func tick(dir: Vector2i, delta: float) -> Vector2i:
		if dir != _dir:
			_dir = dir
			_held = 0.0
			_next = DELAY
			return Vector2i.ZERO
		if dir == Vector2i.ZERO:
			return Vector2i.ZERO
		_held += delta
		if _held < _next:
			return Vector2i.ZERO
		_next += EVERY
		return dir


static func pressed(event: InputEvent, button: JoyButton) -> bool:
	var pad := event as InputEventJoypadButton
	return pad != null and pad.pressed and pad.button_index == button


# A pick on a menu: A, or Start.
static func is_accept(event: InputEvent) -> bool:
	return pressed(event, JOY_BUTTON_A) or pressed(event, JOY_BUTTON_START)


# Any pad event a menu should take as the pad having the focus, rather than
# the mouse: a button, or a stick tipped over (nav, so ask it first).
static func is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion \
			and absf((event as InputEventJoypadMotion).axis_value) > NAV_DOWN


# What a pad's event binds, for the settings' prompt: a button pressed, or a
# trigger pulled; -1 for neither.
static func binding_of(event: InputEvent) -> int:
	var button := event as InputEventJoypadButton
	if button != null and button.pressed:
		return button.button_index
	var motion := event as InputEventJoypadMotion
	if motion != null and motion.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] \
			and motion.axis_value > TRIGGER_DOWN:
		return TRIGGER + motion.axis
	return -1


# Whether the pads are a PlayStation's, by the setting or else by the first
# pad's name. Under Steam Input a DualSense may well be listed as an Xbox
# pad, which is what the setting is for.
static func playstation() -> bool:
	var names := settings.pad_names if settings != null else Names.AUTO
	if names != Names.AUTO:
		return names == Names.PLAYSTATION
	var pads := connected()
	if pads.is_empty():
		return false
	var name := Input.get_joy_name(pads[0]).to_lower()
	for word in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if name.contains(word):
			return true
	return false


const PLAYSTATION_NAMES := {
	JOY_BUTTON_A: "CROSS", JOY_BUTTON_B: "CIRCLE", JOY_BUTTON_X: "SQUARE", JOY_BUTTON_Y: "TRIANGLE",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", TRIGGER_LEFT: "L2", TRIGGER_RIGHT: "R2",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "CREATE",
	JOY_BUTTON_START: "OPTIONS", JOY_BUTTON_GUIDE: "PS", JOY_BUTTON_MISC1: "MUTE", JOY_BUTTON_TOUCHPAD: "TOUCHPAD",
}
const XBOX_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", TRIGGER_LEFT: "LT", TRIGGER_RIGHT: "RT",
	JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS", JOY_BUTTON_BACK: "VIEW",
	JOY_BUTTON_START: "MENU", JOY_BUTTON_GUIDE: "XBOX", JOY_BUTTON_MISC1: "SHARE", JOY_BUTTON_TOUCHPAD: "TOUCHPAD",
}
const DPAD_NAMES := {
	JOY_BUTTON_DPAD_UP: "D-UP", JOY_BUTTON_DPAD_DOWN: "D-DOWN",
	JOY_BUTTON_DPAD_LEFT: "D-LEFT", JOY_BUTTON_DPAD_RIGHT: "D-RIGHT",
}


# A binding's name on the pad in hand, in capitals, as the hints' font writes.
static func name_of(binding: int) -> String:
	if DPAD_NAMES.has(binding):
		return DPAD_NAMES[binding]
	var names := PLAYSTATION_NAMES if playstation() else XBOX_NAMES
	if names.has(binding):
		return names[binding]
	if binding >= JOY_BUTTON_PADDLE1 and binding <= JOY_BUTTON_PADDLE4:
		return "P%d" % (binding - JOY_BUTTON_PADDLE1 + 1)
	return "BUTTON %d" % binding


# A shake of `pads`, if the settings have it: `weak` the light motor, `strong`
# the heavy one, 0 to 1.
static func rumble(pads: Array[int], weak: float, strong: float, seconds: float) -> void:
	if settings != null and not settings.pad_vibration:
		return
	for d in pads:
		Input.start_joy_vibration(d, weak, strong, seconds)
