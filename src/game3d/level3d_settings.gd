# What the 3D preview's Escape menu sets (level3d_menu.gd): the camera, the
# look, what the HUD shows, the sound, how the BTR drives and fires, the keys,
# and the cheats, and the Game tab's two presets of them (PRESETS). Kept in
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
# How the 3D's edges are smoothed: MSAA, its samples ANTIALIAS_MSAA[i], or
# not at all -- the game's, the shop's and the title's splash's (Level3DPixels).
enum Antialias { OFF, MSAA_2X, MSAA_4X, MSAA_8X }
const ANTIALIAS_MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
enum Driving { CLASSIC, FREE }
# Classic: the gun up the screen and the launcher the way the BTR drives, as
# the game's jeep fires; driving free, both along the hull. Modern: both at the
# cursor. Combined: the gun up the screen however the BTR drives, the launcher
# at the cursor.
enum Firing { CLASSIC, MODERN, COMBINED }
# How far the gun and the launcher reach, however the BTR drives and fires --
# it used to be the game's only driving classic, and RANGE driving free
# whatever this said. Classic: the game's, PlayerBullet's, Grenade's and
# PlayerMissile's, about 5 m. Long: the preview's own Level3DGun.RANGE and
# Level3DLauncher.RANGE, 12 and 16 m. Unlimited: until something stops it
# (Level3DGun.unlimited). Aimed at the cursor, a round stops there, no further
# than the reach. LONG is last so that a saved 1 is still UNLIMITED; the menu
# lists them in order of reach (Level3DMenu.REACH_ORDER).
enum Reach { CLASSIC, UNLIMITED, LONG }

# The keys that can be rebound, in the order the menu lists them, and what
# they start as: the preview's keys from before there was a menu. The turret's
# are in DEFAULT_KEYS but not here: the mouse aims it now, and Q and E stay
# as fixed keys for turning it by hand (level3d_preview.gd, _turret_key), not
# bound, not saved.
# "device" sets off what the shop's slot holds (docs/shop-plan.md): nitro,
# mines, the airstrike.
const ACTIONS: Array[String] = ["up", "down", "left", "right", "gun", "rocket", "device"]
const DEFAULT_KEYS := {
	"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D,
	"gun": KEY_L, "rocket": KEY_P, "device": KEY_K, "turret_left": KEY_Q, "turret_right": KEY_E,
}

# The title screen's difficulty (Level3DTitle, Level3DMap.hard).
var hard := false
# Each player's paint (Level3DBtr.PAINTS), as the shop last left it.
var paints: Array[String] = ["olive", "blue"]
var camera := Camera.TILTED
var look := Look.MODERN
# The CRT monitor, over either look.
var crt := false
# The stage's light (Level3DLighting.Preset), the one a run's sunrise ends
# in: the day, Blender's, or the title's low sun.
var light := Level3DLighting.Preset.DAY as int
var resolution := Resolution.NATIVE
var antialias := Antialias.MSAA_4X
# The contour's width by what it is round (Level3DHull.Kind), pixels of a
# frame 1080 high, one of OUTLINES: the stage and the enemies, the players'
# vehicles, the people.
const OUTLINES: Array[float] = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0]
var outline_stage: float = Level3DHull.DEFAULT_PIXELS[Level3DHull.Kind.STAGE]
var outline_vehicles: float = Level3DHull.DEFAULT_PIXELS[Level3DHull.Kind.VEHICLES]
var outline_people: float = Level3DHull.DEFAULT_PIXELS[Level3DHull.Kind.PEOPLE]
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
# The HUD (level3d_preview.gd, _show_state): a master switch, then each of its
# pieces. Minimal by default, as the game's own HUD is: the driving and firing
# modes are settings rather than the state of the run, so they are off, and V
# and M show them for a moment instead (_flash_modes).
enum HudCorner { TOP, BOTTOM }
const HUD_SCALES: Array[float] = [0.75, 1.0, 1.25, 1.5]
var hud := true
var hud_score := true
var hud_lives := true
var hud_pows := true
var hud_modes := false
var hud_pad_arrow := true   # to the rescue helicopter, prisoners aboard
var hud_cheats := true      # a line saying which cheats are on
# HELP over a building with prisoners in it, and over a prisoner long left
# where he is (Level3DFriends' calls), and the rescue crewman's HERE!
# (Level3DRescueCrew). Not the game's: its HELP is the house's.
var hud_help := true
# The controls taught over the jeep as they are first wanted (Level3DHints).
var hud_hints := true
# The overlays' font (Level3DFont.Style): Press Start 2P sharp or smoothed,
# or Black Ops One.
var font := Level3DFont.Style.CLASSIC_SMOOTH
# The three banners (Level3DBanners): STAGE 1 under the Chinook, WARNING on
# the boss's pan, the mission's lines when it is beaten. Under `hud`.
var banner_stage := true
var banner_warning := true
var banner_mission := true
# The reticle in place of the cursor while the mouse aims (Level3DCrosshair).
# Not under `hud`: it is how the mouse is seen, not something the HUD reports.
var hud_crosshair := true
# At the bottom: the enemies come in at the top (Level3DHud says why).
var hud_corner := HudCorner.BOTTOM
# The score on a row of its own over the rest, rather than leading one line:
# a player's corner half as wide, and a little taller (Level3DHud.two_rows).
var hud_two_rows := true
var hud_scale := 1.0
var keys := DEFAULT_KEYS.duplicate()
# The sound (Level3DAudio): original, the original's effects as the game plays
# them; classic, modern's sounds and music on an NES's sound chips, played
# as modern's are; or modern, in 3D, with the engines, the ambience and the
# enemies' fire the original never had; a folder of sounds each. The values
# are Level3DAudio.Mode's, and ORIGINAL came last, so a config saved before
# it still means what it did by its number. The volumes are 0 to 1, onto the
# buses; the enemies' fire has a switch and a volume of its own, since the
# original fired in silence.
enum SoundMode { CLASSIC, MODERN, ORIGINAL }
var sound_mode := SoundMode.MODERN
# The modern boss music: following the fight, a layer a tank on the field
# (Level3DAudio.ADAPTIVE), or the same parts as one track.
enum BossMusic { ADAPTIVE, LINEAR }
var boss_music := BossMusic.LINEAR   # the default: adaptive was tried as it and turned down
var master_volume := 1.0
var music_volume := 0.8
var effects_volume := 1.0
var enemy_fire := true
var enemy_fire_volume := 0.8
# Each of the modern mode's sounds on its own, Level3DAudio.SOUNDS' name ->
# 0 to Level3DAudio.MAX_GAIN over the level it was set to; one left out is at 1.
var sound_gains := {}

# The Game tab's mode: a preset of the settings above, PRESETS[mode] the
# value it gives each, set by name. Not saved: it is read back off the
# settings (preset()), so that one changed on its own tab makes it CUSTOM,
# and a config saved before there were modes comes up as whichever it is.
# 8-bit is the NES game: its sounds on the NES's chips, the jeep's driving
# and firing and reach, the pixel font sharp, the frame in pixels on a CRT.
# Modern is the preview's own of each of them.
enum Preset { EIGHT_BIT, MODERN, CUSTOM }
const PRESETS := [
	{"sound_mode": SoundMode.CLASSIC, "driving": Driving.CLASSIC, "firing": Firing.CLASSIC,
			"reach": Reach.CLASSIC, "font": Level3DFont.Style.CLASSIC, "look": Look.PIXELS, "crt": true},
	{"sound_mode": SoundMode.MODERN, "driving": Driving.FREE, "firing": Firing.MODERN,
			"reach": Reach.LONG, "font": Level3DFont.Style.MODERN, "look": Look.MODERN, "crt": false},
]


func preset() -> Preset:
	for mode in PRESETS.size():
		var values: Dictionary = PRESETS[mode]
		if values.keys().all(func(name: String): return get(name) == values[name]):
			return mode as Preset
	return Preset.CUSTOM


func apply_preset(mode: Preset) -> void:
	if mode == Preset.CUSTOM:
		return
	var values: Dictionary = PRESETS[mode]
	for name in values:
		set(name, values[name])


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
	hard = config.get_value("game", "hard", hard)
	for i in paints.size():
		var paint: String = str(config.get_value("game", "paint_%d" % (i + 1), paints[i]))
		if Level3DBtr.PAINTS.any(func(p: Dictionary): return p.id == paint):
			paints[i] = paint
	camera = clampi(config.get_value("graphics", "camera", camera), 0, Camera.size() - 1)
	resolution = clampi(config.get_value("graphics", "resolution", resolution), 0, Resolution.size() - 1)
	antialias = clampi(config.get_value("graphics", "antialias", antialias), 0, Antialias.size() - 1)
	light = clampi(config.get_value("graphics", "light", light), 0, Level3DLighting.NAMES.size() - 1)
	if config.has_section_key("graphics", "render"):
		look = clampi(config.get_value("graphics", "render", look), 0, Look.size() - 1)
		crt = config.get_value("graphics", "crt", crt)
	else:
		# Saved when the CRT was a third look: 0 modern, 1 CRT, 2 pixels.
		var old: int = config.get_value("graphics", "look", 0)
		look = Look.PIXELS if old == 2 else Look.MODERN
		crt = old == 1
	outline_stage = _outline(config.get_value("graphics", "outline_stage", outline_stage), outline_stage)
	outline_vehicles = _outline(config.get_value("graphics", "outline_vehicles", outline_vehicles), outline_vehicles)
	outline_people = _outline(config.get_value("graphics", "outline_people", outline_people), outline_people)
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
	hud_modes = config.get_value("interface", "modes", hud_modes)
	hud_pad_arrow = config.get_value("interface", "pad_arrow", hud_pad_arrow)
	hud_help = config.get_value("interface", "help", hud_help)
	hud_hints = config.get_value("interface", "hints", hud_hints)
	font = clampi(config.get_value("interface", "font", font), 0, Level3DFont.Style.size() - 1)
	hud_cheats = config.get_value("interface", "cheats", hud_cheats)
	hud_crosshair = config.get_value("interface", "crosshair", hud_crosshair)
	banner_stage = config.get_value("interface", "banner_stage", banner_stage)
	banner_warning = config.get_value("interface", "banner_warning", banner_warning)
	banner_mission = config.get_value("interface", "banner_mission", banner_mission)
	hud_corner = clampi(config.get_value("interface", "corner", hud_corner), 0, HudCorner.size() - 1)
	hud_two_rows = config.get_value("interface", "two_rows", hud_two_rows)
	var scale = config.get_value("interface", "scale", hud_scale)
	hud_scale = float(scale) if (scale is int or scale is float) and HUD_SCALES.has(float(scale)) else 1.0
	sound_mode = clampi(config.get_value("sound", "mode", sound_mode), 0, SoundMode.size() - 1)
	boss_music = clampi(config.get_value("sound", "boss_music", boss_music), 0, BossMusic.size() - 1)
	master_volume = _volume(config.get_value("sound", "master", master_volume))
	music_volume = _volume(config.get_value("sound", "music", music_volume))
	effects_volume = _volume(config.get_value("sound", "effects", effects_volume))
	enemy_fire = config.get_value("sound", "enemy_fire", enemy_fire)
	enemy_fire_volume = _volume(config.get_value("sound", "enemy_fire_volume", enemy_fire_volume))
	sound_gains = {}
	if config.has_section("sound_gains"):
		for name in config.get_section_keys("sound_gains"):
			var saved = config.get_value("sound_gains", name)
			if Level3DAudio.SOUNDS.has(name) and (saved is int or saved is float):
				sound_gains[name] = clampf(float(saved), 0.0, Level3DAudio.MAX_GAIN)
	for action in ACTIONS:
		var saved = config.get_value("keys", action, DEFAULT_KEYS[action])
		if saved is int and saved != KEY_NONE:
			keys[action] = saved


static func _volume(saved) -> float:
	return clampf(float(saved), 0.0, 1.0) if saved is int or saved is float else 1.0


static func _outline(saved, otherwise: float) -> float:
	return float(saved) if (saved is int or saved is float) and OUTLINES.has(float(saved)) else otherwise


static func _rate(saved) -> float:
	return float(saved) if (saved is int or saved is float) and RATES.has(float(saved)) else 1.0


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "hard", hard)
	for i in paints.size():
		config.set_value("game", "paint_%d" % (i + 1), paints[i])
	config.set_value("graphics", "camera", camera)
	config.set_value("graphics", "render", look)
	config.set_value("graphics", "resolution", resolution)
	config.set_value("graphics", "antialias", antialias)
	config.set_value("graphics", "crt", crt)
	config.set_value("graphics", "light", light)
	config.set_value("graphics", "outline_stage", outline_stage)
	config.set_value("graphics", "outline_vehicles", outline_vehicles)
	config.set_value("graphics", "outline_people", outline_people)
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
	config.set_value("interface", "modes", hud_modes)
	config.set_value("interface", "pad_arrow", hud_pad_arrow)
	config.set_value("interface", "help", hud_help)
	config.set_value("interface", "hints", hud_hints)
	config.set_value("interface", "font", font)
	config.set_value("interface", "cheats", hud_cheats)
	config.set_value("interface", "crosshair", hud_crosshair)
	config.set_value("interface", "banner_stage", banner_stage)
	config.set_value("interface", "banner_warning", banner_warning)
	config.set_value("interface", "banner_mission", banner_mission)
	config.set_value("interface", "corner", hud_corner)
	config.set_value("interface", "two_rows", hud_two_rows)
	config.set_value("interface", "scale", hud_scale)
	config.set_value("sound", "mode", sound_mode)
	config.set_value("sound", "boss_music", boss_music)
	config.set_value("sound", "master", master_volume)
	config.set_value("sound", "music", music_volume)
	config.set_value("sound", "effects", effects_volume)
	config.set_value("sound", "enemy_fire", enemy_fire)
	config.set_value("sound", "enemy_fire_volume", enemy_fire_volume)
	# Only what was moved off 1, so that a sound added later starts at its level.
	for name in sound_gains:
		if not is_equal_approx(sound_gains[name], 1.0):
			config.set_value("sound_gains", name, sound_gains[name])
	for action in ACTIONS:
		config.set_value("keys", action, key(action))
	config.save(SAVE_PATH)
