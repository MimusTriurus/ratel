class_name ButtonMapping
extends RefCounted

var key_up: Key = KEY_W
var key_down: Key = KEY_S
var key_left: Key = KEY_A
var key_right: Key = KEY_D
var key_grenade: Key = KEY_X
var key_gun: Key = KEY_Z

var controller: bool
var controller_index: int
var controller_grenade: int = JOY_BUTTON_A
var controller_gun: int = JOY_BUTTON_B

var gun_key_mapped: bool

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

const SAVE_PATH := "user://buttons.cfg"

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
	gun_key_mapped = o.gun_key_mapped
	controller = o.controller
	controller_index = o.controller_index
	controller_grenade = o.controller_grenade
	controller_gun = o.controller_gun
	mouse_aim = o.mouse_aim
	turbo = o.turbo


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
	cfg.set_value("keys", "gun_mapped", gun_key_mapped)
	cfg.set_value("pad", "enabled", controller)
	cfg.set_value("pad", "index", controller_index)
	cfg.set_value("pad", "grenade", controller_grenade)
	cfg.set_value("pad", "gun", controller_gun)
	cfg.set_value("mouse", "aim", mouse_aim)
	cfg.set_value("gun", "turbo", turbo)
	cfg.save(SAVE_PATH)


func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	key_up = cfg.get_value("keys", "up", key_up)
	key_down = cfg.get_value("keys", "down", key_down)
	key_left = cfg.get_value("keys", "left", key_left)
	key_right = cfg.get_value("keys", "right", key_right)
	key_grenade = cfg.get_value("keys", "grenade", key_grenade)
	key_gun = cfg.get_value("keys", "gun", key_gun)
	gun_key_mapped = cfg.get_value("keys", "gun_mapped", gun_key_mapped)
	controller = cfg.get_value("pad", "enabled", controller)
	controller_index = cfg.get_value("pad", "index", controller_index)
	controller_grenade = cfg.get_value("pad", "grenade", controller_grenade)
	controller_gun = cfg.get_value("pad", "gun", controller_gun)
	mouse_aim = cfg.get_value("mouse", "aim", mouse_aim)
	turbo = cfg.get_value("gun", "turbo", turbo)
