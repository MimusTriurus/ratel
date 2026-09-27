# What the 3D preview's Escape menu sets (level3d_menu.gd): the camera, the
# look, how the BTR drives and fires, the keys, and three cheats. Kept in
# user://preview3d.cfg, apart from the game's buttons.cfg and audio.cfg: the
# preview is not the game, and its keys are not the game's.
#
# A --shot or an --obstacle-map run neither loads nor saves it, so what a
# shot shows does not depend on what was last picked in the menu.
class_name Level3DSettings
extends RefCounted

const SAVE_PATH := "user://preview3d.cfg"

enum Camera { TOP, TILTED }
enum Look { MODERN, CRT, PIXELS }
enum Driving { CLASSIC, FREE }
# Classic: the gun up the screen and the launcher the way the BTR drives, as
# the game's jeep fires; driving free, both along the hull. Modern: both at the
# cursor. Combined: the gun as classic, the launcher at the cursor.
enum Firing { CLASSIC, MODERN, COMBINED }

# The keys that can be rebound, in the order the menu lists them, and what
# they start as: the preview's keys from before there was a menu.
const ACTIONS: Array[String] = ["up", "down", "left", "right", "gun", "rocket",
		"turret_left", "turret_right"]
const DEFAULT_KEYS := {
	"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
	"gun": KEY_L, "rocket": KEY_P, "turret_left": KEY_Q, "turret_right": KEY_E,
}

var camera := Camera.TILTED
var look := Look.MODERN
var driving := Driving.CLASSIC
var firing := Firing.CLASSIC
var infinite_lives := false
var wall_hack := false
var bullet_hack := false
var keys := DEFAULT_KEYS.duplicate()


func key(action: String) -> Key:
	return keys.get(action, DEFAULT_KEYS[action])


# The action a key is bound to, or "".
func action_of(keycode: Key) -> String:
	for action in ACTIONS:
		if key(action) == keycode:
			return action
	return ""


# Binds `keycode` to `action`; whatever had it before takes `action`'s old key,
# so no two actions ever share one and none is left without.
func bind(action: String, keycode: Key) -> void:
	var other := action_of(keycode)
	if other != "" and other != action:
		keys[other] = key(action)
	keys[action] = keycode


func reset_keys() -> void:
	keys = DEFAULT_KEYS.duplicate()


func load_saved() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	camera = clampi(config.get_value("graphics", "camera", camera), 0, Camera.size() - 1)
	look = clampi(config.get_value("graphics", "look", look), 0, Look.size() - 1)
	driving = clampi(config.get_value("controls", "driving", driving), 0, Driving.size() - 1)
	firing = clampi(config.get_value("controls", "firing", firing), 0, Firing.size() - 1)
	infinite_lives = config.get_value("cheats", "infinite_lives", infinite_lives)
	wall_hack = config.get_value("cheats", "wall_hack", wall_hack)
	bullet_hack = config.get_value("cheats", "bullet_hack", bullet_hack)
	for action in ACTIONS:
		var saved = config.get_value("keys", action, DEFAULT_KEYS[action])
		if saved is int and saved != KEY_NONE:
			keys[action] = saved


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "camera", camera)
	config.set_value("graphics", "look", look)
	config.set_value("controls", "driving", driving)
	config.set_value("controls", "firing", firing)
	config.set_value("cheats", "infinite_lives", infinite_lives)
	config.set_value("cheats", "wall_hack", wall_hack)
	config.set_value("cheats", "bullet_hack", bullet_hack)
	for action in ACTIONS:
		config.set_value("keys", action, key(action))
	config.save(SAVE_PATH)
