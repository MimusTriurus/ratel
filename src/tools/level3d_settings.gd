# What the 3D preview's Escape menu sets (level3d_menu.gd): the camera, the
# look, what the HUD shows, how the BTR drives and fires, the keys, and the
# cheats. Kept in
# user://preview3d.cfg, apart from the game's buttons.cfg and audio.cfg: the
# preview is not the game, and its keys are not the game's.
#
# A --shot or an --obstacle-map run neither loads nor saves it, so what a
# shot shows does not depend on what was last picked in the menu.
class_name Level3DSettings
extends RefCounted

const SAVE_PATH := "user://preview3d.cfg"

enum Camera { TOP, TILTED }
enum Look { MODERN, PIXELS }
# How many pixels the 3D is drawn at: the screen's own, or a width of its
# own, RESOLUTIONS[i], scaled to the screen. The HUD and the menu are drawn at
# the screen's either way (level3d_preview.gd, _apply_resolution).
enum Resolution { NATIVE, GAME, FULL_HD, HD }
const RESOLUTIONS := [Vector2i.ZERO, Vector2i(2048, 1152), Vector2i(1920, 1080), Vector2i(1280, 720)]
enum Driving { CLASSIC, FREE }
# Classic: the gun up the screen and the launcher the way the BTR drives, as
# the game's jeep fires; driving free, both along the hull. Modern: both at the
# cursor. Combined: the gun up the screen however the BTR drives, the launcher
# at the cursor.
enum Firing { CLASSIC, MODERN, COMBINED }
# Classic: the game's reach, driving classic, and to the cursor or RANGE
# driving free. Unlimited: until something stops it (Level3DGun.unlimited).
enum Reach { CLASSIC, UNLIMITED }

# The keys that can be rebound, in the order the menu lists them, and what
# they start as: the preview's keys from before there was a menu. The turret's
# are in DEFAULT_KEYS but not here: the mouse aims it now, and Q and E stay
# as fixed keys for turning it by hand (level3d_preview.gd, _turret_key), not
# bound, not saved.
const ACTIONS: Array[String] = ["up", "down", "left", "right", "gun", "rocket"]
const DEFAULT_KEYS := {
	"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
	"gun": KEY_L, "rocket": KEY_P, "turret_left": KEY_Q, "turret_right": KEY_E,
}

var camera := Camera.TILTED
var look := Look.MODERN
# The CRT monitor, over either look.
var crt := false
var resolution := Resolution.NATIVE
var driving := Driving.CLASSIC
var firing := Firing.CLASSIC
var reach := Reach.CLASSIC
var infinite_lives := false
var wall_hack := false
var bullet_hack := false
# The rate cheats: how many times faster the gun fires and the launcher
# reloads, one of RATES -- half as fast as well.
const RATES: Array[float] = [0.5, 1.0, 2.0, 4.0]
var gun_rate := 1.0
var launcher_rate := 1.0
# The HUD (level3d_preview.gd, _set_score): a master switch, then each of its
# pieces. Minimal by default, as the game's own HUD is: the driving and firing
# modes are settings rather than the state of the run, so they are off, and V
# and M show them for a moment instead (_flash_modes).
enum HudCorner { TOP, BOTTOM }
const HUD_SCALES: Array[float] = [0.75, 1.0, 1.25, 1.5]
var hud := true
var hud_score := true
var hud_lives := true
var hud_pows := true
var hud_weapon := true
var hud_modes := false
var hud_pad_arrow := true   # to the rescue helicopter, prisoners aboard
# The reticle in place of the cursor while the mouse aims (Level3DCrosshair).
# Not under `hud`: it is how the mouse is seen, not something the HUD reports.
var hud_crosshair := true
var hud_corner := HudCorner.TOP
var hud_scale := 1.0
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
	resolution = clampi(config.get_value("graphics", "resolution", resolution), 0, Resolution.size() - 1)
	if config.has_section_key("graphics", "render"):
		look = clampi(config.get_value("graphics", "render", look), 0, Look.size() - 1)
		crt = config.get_value("graphics", "crt", crt)
	else:
		# Saved when the CRT was a third look: 0 modern, 1 CRT, 2 pixels.
		var old: int = config.get_value("graphics", "look", 0)
		look = Look.PIXELS if old == 2 else Look.MODERN
		crt = old == 1
	driving = clampi(config.get_value("controls", "driving", driving), 0, Driving.size() - 1)
	firing = clampi(config.get_value("controls", "firing", firing), 0, Firing.size() - 1)
	reach = clampi(config.get_value("controls", "reach", reach), 0, Reach.size() - 1)
	infinite_lives = config.get_value("cheats", "infinite_lives", infinite_lives)
	wall_hack = config.get_value("cheats", "wall_hack", wall_hack)
	bullet_hack = config.get_value("cheats", "bullet_hack", bullet_hack)
	gun_rate = _rate(config.get_value("cheats", "gun_rate", gun_rate))
	launcher_rate = _rate(config.get_value("cheats", "launcher_rate", launcher_rate))
	hud = config.get_value("interface", "hud", hud)
	hud_score = config.get_value("interface", "score", hud_score)
	hud_lives = config.get_value("interface", "lives", hud_lives)
	hud_pows = config.get_value("interface", "pows", hud_pows)
	hud_weapon = config.get_value("interface", "weapon", hud_weapon)
	hud_modes = config.get_value("interface", "modes", hud_modes)
	hud_pad_arrow = config.get_value("interface", "pad_arrow", hud_pad_arrow)
	hud_crosshair = config.get_value("interface", "crosshair", hud_crosshair)
	hud_corner = clampi(config.get_value("interface", "corner", hud_corner), 0, HudCorner.size() - 1)
	var scale = config.get_value("interface", "scale", hud_scale)
	hud_scale = float(scale) if (scale is int or scale is float) and HUD_SCALES.has(float(scale)) else 1.0
	for action in ACTIONS:
		var saved = config.get_value("keys", action, DEFAULT_KEYS[action])
		if saved is int and saved != KEY_NONE:
			keys[action] = saved


static func _rate(saved) -> float:
	return float(saved) if (saved is int or saved is float) and RATES.has(float(saved)) else 1.0


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "camera", camera)
	config.set_value("graphics", "render", look)
	config.set_value("graphics", "resolution", resolution)
	config.set_value("graphics", "crt", crt)
	config.set_value("controls", "driving", driving)
	config.set_value("controls", "firing", firing)
	config.set_value("controls", "reach", reach)
	config.set_value("cheats", "infinite_lives", infinite_lives)
	config.set_value("cheats", "wall_hack", wall_hack)
	config.set_value("cheats", "bullet_hack", bullet_hack)
	config.set_value("cheats", "gun_rate", gun_rate)
	config.set_value("cheats", "launcher_rate", launcher_rate)
	config.set_value("interface", "hud", hud)
	config.set_value("interface", "score", hud_score)
	config.set_value("interface", "lives", hud_lives)
	config.set_value("interface", "pows", hud_pows)
	config.set_value("interface", "weapon", hud_weapon)
	config.set_value("interface", "modes", hud_modes)
	config.set_value("interface", "pad_arrow", hud_pad_arrow)
	config.set_value("interface", "crosshair", hud_crosshair)
	config.set_value("interface", "corner", hud_corner)
	config.set_value("interface", "scale", hud_scale)
	for action in ACTIONS:
		config.set_value("keys", action, key(action))
	config.save(SAVE_PATH)
