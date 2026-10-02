class_name ButtonMapping
extends RefCounted

var key_up: Key = KEY_W
var key_down: Key = KEY_S
var key_left: Key = KEY_A
var key_right: Key = KEY_D
# O and P, not the original's X and Z: the first player's hand stays on the
# right of the board's letters while the second player's is on the arrows, and
# P is a weapon rather than the pause it was (HumanInput lets a bound key win).
var key_grenade: Key = KEY_P
var key_gun: Key = KEY_O
# Which of a pair of keys the weapons are: the second player's are the right
# Ctrl and Alt, which Godot only tells apart by an event's location, so
# HumanInput tracks them from events. UNSPECIFIED is either, as before.
var key_grenade_location: KeyLocation = KEY_LOCATION_UNSPECIFIED
var key_gun_location: KeyLocation = KEY_LOCATION_UNSPECIFIED

var controller: bool
var controller_index: int
var controller_grenade: int = JOY_BUTTON_A
var controller_gun: int = JOY_BUTTON_B

# Whether key_gun is the gun, or the original's fallback set is (HumanInput).
var gun_key_mapped: bool = true

# Mouse aiming: the cursor sets the weapon angle, LMB fires the machine gun and
# RMB throws the grenade/missile. Off falls back to the original scheme, where
# the gun always fires north and the grenade follows the jeep.
var mouse_aim: bool = true

# Turbo: holding the gun fires as a turbo pad would, a round every
# Player.TURBO_DELAY ticks, where the original fires one every GUN_ARMED_DELAY
# (45) and wants the button tapped for more. On by default, because mouse
# aiming means holding LMB, and two rounds a second read as a broken gun.
# Player.MAX_BULLETS still caps what is in flight.
var turbo: bool = true

# A cheat, not in the original: nothing kills the jeep -- no round, shell,
# mine, ram or blast -- as nothing does while it flashes after a respawn
# (Player.invincible), but for good and without the flash. Off by default;
# switched from the in-game menu's options page.
var god_mode: bool = false

const SAVE_PATH := "user://buttons.cfg"
const SAVE_PATH_2 := "user://buttons2.cfg"

# Where this mapping persists: the first player's in buttons.cfg, the second's
# in buttons2.cfg. Not copied by copy_from -- a copy is the same player's.
var save_path: String = SAVE_PATH

# Every persisted field. InputMode snapshots the mapping on entry and restores
# it through this when the remap is cancelled, and reset_to_defaults() copies
# from a fresh instance.
func copy_from(o: ButtonMapping) -> void:
	key_up = o.key_up
	key_down = o.key_down
	key_left = o.key_left
	key_right = o.key_right
	key_grenade = o.key_grenade
	key_gun = o.key_gun
	key_grenade_location = o.key_grenade_location
	key_gun_location = o.key_gun_location
	gun_key_mapped = o.gun_key_mapped
	controller = o.controller
	controller_index = o.controller_index
	controller_grenade = o.controller_grenade
	controller_gun = o.controller_gun
	mouse_aim = o.mouse_aim
	turbo = o.turbo
	god_mode = o.god_mode


# The second player's defaults: the arrows, right Alt for the gun and right
# Ctrl for the grenade, and the first pad the first player is not using. No
# mouse -- there is one, and it is the first player's. Saved to its own file;
# InputMode remaps it (Modes.INPUT_2).
static func second_player(first: ButtonMapping) -> ButtonMapping:
	var m := ButtonMapping.new()
	m.save_path = SAVE_PATH_2
	m.key_up = KEY_UP
	m.key_down = KEY_DOWN
	m.key_left = KEY_LEFT
	m.key_right = KEY_RIGHT
	m.key_gun = KEY_ALT
	m.key_gun_location = KEY_LOCATION_RIGHT
	m.key_grenade = KEY_CTRL
	m.key_grenade_location = KEY_LOCATION_RIGHT
	m.controller = true
	m.controller_index = 1 if first.controller and first.controller_index == 0 else 0
	m.mouse_aim = false
	return m


# Whether a key is one of the six controls, so that HumanInput can let it be
# that rather than the pause or a fallback gun key.
func claims(key: Key) -> bool:
	return key == key_up or key == key_down or key == key_left \
		or key == key_right or key == key_grenade or key == key_gun


# claims, with the side of the board: the second player's right Ctrl leaves
# the left one free. A direction is either side.
func claims_at(key: Key, location: KeyLocation) -> bool:
	if key == key_grenade and _same_side(location, key_grenade_location):
		return true
	if key == key_gun and _same_side(location, key_gun_location):
		return true
	return key == key_up or key == key_down or key == key_left or key == key_right


static func _same_side(a: KeyLocation, b: KeyLocation) -> bool:
	return a == KEY_LOCATION_UNSPECIFIED or b == KEY_LOCATION_UNSPECIFIED or a == b


func duplicate_mapping() -> ButtonMapping:
	var copy := ButtonMapping.new()
	copy.copy_from(self)
	return copy


func reset_to_defaults() -> void:
	copy_from(ButtonMapping.new())


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("keys", "up", key_up)
	cfg.set_value("keys", "down", key_down)
	cfg.set_value("keys", "left", key_left)
	cfg.set_value("keys", "right", key_right)
	cfg.set_value("keys", "grenade", key_grenade)
	cfg.set_value("keys", "gun", key_gun)
	cfg.set_value("keys", "grenade_location", key_grenade_location)
	cfg.set_value("keys", "gun_location", key_gun_location)
	cfg.set_value("keys", "gun_mapped", gun_key_mapped)
	cfg.set_value("pad", "enabled", controller)
	cfg.set_value("pad", "index", controller_index)
	cfg.set_value("pad", "grenade", controller_grenade)
	cfg.set_value("pad", "gun", controller_gun)
	cfg.set_value("mouse", "aim", mouse_aim)
	cfg.set_value("gun", "turbo", turbo)
	cfg.set_value("cheats", "god_mode", god_mode)
	cfg.save(save_path)


func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	key_up = cfg.get_value("keys", "up", key_up)
	key_down = cfg.get_value("keys", "down", key_down)
	key_left = cfg.get_value("keys", "left", key_left)
	key_right = cfg.get_value("keys", "right", key_right)
	key_grenade = cfg.get_value("keys", "grenade", key_grenade)
	key_gun = cfg.get_value("keys", "gun", key_gun)
	key_grenade_location = cfg.get_value("keys", "grenade_location", key_grenade_location)
	key_gun_location = cfg.get_value("keys", "gun_location", key_gun_location)
	gun_key_mapped = cfg.get_value("keys", "gun_mapped", gun_key_mapped)
	controller = cfg.get_value("pad", "enabled", controller)
	controller_index = cfg.get_value("pad", "index", controller_index)
	controller_grenade = cfg.get_value("pad", "grenade", controller_grenade)
	controller_gun = cfg.get_value("pad", "gun", controller_gun)
	mouse_aim = cfg.get_value("mouse", "aim", mouse_aim)
	turbo = cfg.get_value("gun", "turbo", turbo)
	god_mode = cfg.get_value("cheats", "god_mode", god_mode)
