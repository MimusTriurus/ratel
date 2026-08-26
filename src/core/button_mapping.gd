class_name ButtonMapping
extends RefCounted

var key_up: Key = KEY_UP
var key_down: Key = KEY_DOWN
var key_left: Key = KEY_LEFT
var key_right: Key = KEY_RIGHT
var key_grenade: Key = KEY_X
var key_gun: Key = KEY_Z

var controller: bool
var controller_index: int
var controller_grenade: int = JOY_BUTTON_A
var controller_gun: int = JOY_BUTTON_B

var gun_key_mapped: bool

const SAVE_PATH := "user://buttons.cfg"

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
