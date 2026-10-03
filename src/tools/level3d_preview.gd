# A look at the low-poly 3D remake of stage 1 inside Godot, on its own scene
# rather than in the game, with the BTR driving on it:
#
#     godot --path . src/tools/level3d_preview.tscn
#
# Nothing here is part of the game, which stays 2D. The level is built from
# its level file, assets/level3d/stage-0.json, by tools/blender/build_level.py
# on top of resources/3d/jackal_stage1_lowpoly.blend, and comes in as
# jackal_stage1.glb, exported from Blender (visible objects, modifiers applied, no animation; the
# buildings that can be destroyed come separately, see _add_destructibles). It
# is a .glb rather than the .blend itself because project.godot keeps
# import/blender/enabled off, and the glTF route does not need Blender on the
# machine that imports it. The BTR is ratel_btr.glb; how it drives is
# level3d_btr.gd.
#
# The light is Blender's: the same sun direction, the scene's leftover 1000 W
# point light over the start area, the world colour as ambient light (on the
# water still; everything else has a grey one, the two-tone shadows' SHADE),
# and a linear tonemapper because the view transform was Standard. Strengths could
# not simply be converted -- Forward+ and Compatibility disagree with each
# other by about a factor of two -- so the sun's gain per renderer was measured
# against the same frame rendered in Blender (sand at the start of the stage).
# The project renders with Compatibility; add --rendering-method forward_plus
# for the closer match. The ocean's procedural Blender shader does not survive
# glTF; level3d_ocean.gdshader stands in for it, fed by the shore distance the
# export bakes into the ocean's vertex colours.
#
# The default view is a tilted perspective one, following the BTR up the
# stage; Tab switches to the game's, straight down, orthographic, the frame
# exactly as wide as the level, 16:9. The controls are the game's -- WASD to
# drive, the left button or L to fire the gun up the screen, the right button
# or P for the rocket, as the game's jeep does; M hands the aim to the mouse, or
# half of it --
# with the tank bench's orders from BlenderMCP/godot moved to the middle
# button. WASD drives one of two ways
# (level3d_btr.gd): classic, the game's jeep, eight directions at its speed,
# or free, a throttle and a wheel:
#
#   Esc                    the menu (level3d_menu.gd): continue, settings,
#                          main menu (the title screen, level3d_title.gd,
#                          which the preview opens on), quit. The settings -- camera, look (modern or
#                          pixels, a CRT over either), the HUD, keys, driving,
#                          firing, reach (the game's, long or unlimited), and the
#                          cheats: infinite lives, wall hack, bullet hack,
#                          the gun's and the launcher's rate -- are
#                          Level3DSettings, kept in user://preview3d.cfg; the
#                          keys below are its defaults, and a --shot ignores it
#   W / A / S / D          classic: up, left, down, right, and the diagonals
#                          free: drive and steer by hand
#                          either: cancels the order
#   V                      classic / free driving, shown by the score for a
#                          moment (for good: the menu's Interface tab)
#   M                      the firing: classic, the game's -- driving classic
#                          the gun up the screen and the rocket the way the
#                          BTR drives, driving free both along the hull;
#                          modern, both at the cursor; combined, the gun up
#                          the screen and the rocket at the cursor
#   left button (held), L  machine gun, level3d_gun.gd
#   right click, P         rocket, level3d_rocket.gd -- L and P are for
#                          classic driving with the mouse off, under the
#                          right hand while the left is on WASD. Classic,
#                          both are the game's weapons: the gun fires on the
#                          press and, held, slowly or at turbo's rate (T
#                          toggles; the game's setting to start with), and the
#                          rocket goes while the button is held, one at a time
#   middle click           drive there (shift: add a waypoint)
#   Backspace              stop
#   Q / E                  turn the turret by hand while held; fixed keys,
#                          not in the menu, and given up to any action
#                          bound to them there
#   R                      fly the BTR in again, rebuild what was blown up
#                          and bring the bunkers' guns, the soldiers, the boats,
#                          the tanks and the boss back
#   Space                  skip the Chinook: the BTR is simply there
#   wheel, arrows          scroll the camera off the BTR; C follows it again
#   + / -                  zoom
#   Tab                    tilted view / top view
#   Home / End             start / end of the level
#   G                      the palms' and the trees' sway smooth / stepped,
#                          held poses at 8 a second (level3d_wind.gd);
#                          --wind-steps starts stepped, --no-wind stills them
#   H                      the rockets and the mortar's bomb cast a real
#                          shadow in the sun, or have a spot on the ground
#                          under them (Level3DFx.spot); from the next one
#                          fired; --spots starts with spots. The rounds fly
#                          low and always cast one
#
# Like the map editor it can render one view and quit (a real window is needed,
# --headless has no framebuffer to read back):
#
#     godot --path . --windowed --resolution 1280x720 src/tools/level3d_preview.tscn \
#         -- --shot out.png <position 0-1 or x,z> <zoom> <top|tilt> [<seconds> <x,z> ...] \
#            [--destroy <name>,...] [--fire <x,z>] [--rocket <x,z>[@<seconds>]] [--immortal]
#            [--at <x,z>] [--free] [--hold <keys>@<from>-<to>[,...]] [--weapon <0-3>]
#            [--intro] [--pows <n>] [--score <n>] [--summary <seconds>] [--strip <frames>,<seconds>[,<px>]] [--die <seconds>]
#
# The bunkers' guns, the enemy soldiers, the two boats on the river, the two
# brown tanks and the boss's four heavy tanks at the top of the stage fight back
# as they do in the game (level3d_guns.gd, level3d_soldiers.gd,
# level3d_boats.gd, level3d_tanks.gd, level3d_boss.gd, on the game's own map
# through level3d_map.gd); the boss takes the camera to its arena and keeps it
# there, as the game's does. One round kills the BTR, which comes back where
# it died after a pause, blinking while it cannot be hit, for one of four spare
# lives; with none left the stage starts again. --immortal lets the enemies'
# rounds pass it (running into a gun or a tank still kills it), as the menu's
# bullet hack does, and a --shot prints what the enemies do.
#
# The frame is taken that many seconds later; with waypoints the BTR is sent
# along them first (level coordinates: x across, z up the stage is negative)
# and the camera follows it. --destroy sets the named buildings off at the
# start -- DESTRUCTIBLE_NAMES has the names -- --fire aims at x,z and holds
# the trigger down from the start, and --rocket aims at x,z and sends one
# rocket as soon as the launcher has come round, or that many seconds in.
# --at puts the BTR at x,z to begin with instead of at START. --free drives
# the free way; --hold holds WASD, L or P down from one second to another, as
# many spans as are given (wd@0-1.5,a@2-3), which is how the classic keys
# are checked; a span after 2: is the second player's (2:s@0-3). --weapon starts with what the prisoners would have given: 0 the
# grenade, 1 to 3 the missile and its two upgrades. --pows starts with that
# many prisoners aboard, every player, for the rescue helicopter, and --score
# with that score, for the extra life at 20000. --summary shows the mission's
# summary that many seconds in, as if the boss were beaten. --strip takes that many
# frames instead of one, that many seconds apart from the first, and lays the
# middle <px> square of each (512 unless given) out four to a row in the one
# file: a blast from start to finish, which one frame never catches. --die
# blows the BTR up that many seconds in, for its wreck (level3d_wreck.gd).
#
# The BTR's rear wheels and the tanks' tracks leave marks on the ground that
# fade in under seven seconds (level3d_tracks.gd); the game leaves none. They
# raise dust as they go, and everything that drives puffs its exhaust
# (level3d_puffs.gd), which the game draws neither of.
#
# The prisoners the BTR picks up go home by helicopter, as the game's do: one
# flies up the stage on row 161 and lands on the Helipad, and the prisoners
# get off by it and walk aboard while the BTR waits east of it
# (level3d_rescue.gd).
#
# --file <res:// path> plays another level file than stage 1's, one the level
# editor made (src/tools/level_editor.tscn), with --level its built glb: its
# grid, its entities, its frame, and a start and a landing as far from its
# south end as stage 1's are from its own. Stage 1's own buildings that are
# blown up are not in it; its Gate, Barracks* and Hangar objects are.
#
# The stage opens as the game's does: a Chinook flies the BTR in, backs it out
# down its ramp and flies off; the BTR is the player's, at IntroPlayer's spot
# rather than START, as soon as it is out, not once the Chinook has gone as in
# the game (level3d_chinook.gd). A --shot starts
# without it, at START, unless --intro is given, when the seconds count from
# the Chinook's arrival.
#
# --no-chinook skips the Chinook's run at every start of a run, as Space
# does: the jeep is simply there. --boss starts every run BOSS_LEAD_ROWS
# below the boss's trigger, a few seconds' drive from the pan, with the
# soldiers, tanks and boats on the way left unspawned (_start_flags). Both
# apply to the title screen's games and to R as well as to the first.
# docs/preview3d-options.md lists every option.
#
# The vehicle is the jeep; --btr, with or without --shot, drives the BTR
# instead (level3d_btr.gd, VEHICLES): the same driving, stiffer springs and
# no aerials.
#
# The soldiers are the model sheet's trooper (level3d_soldiers.gd, MODEL).
# --level <res:// path> plays another glb of the stage in place of
# LEVEL_PATH: one built from the level file by tools/blender/build_level.py.
# Its ground runs to the level's bounds, so the camera's frame is then the
# file's terrain.frame rather than measured off the meshes.
#
# The dead lie where they fell; --fade-corpses
# sinks them away as the game fades them (level3d_soldiers.gd, fade_corpses).
#
# --players 2, or the Escape menu's game for two, is two-player co-op, as the
# NES game had and the 2D game's title screen offers: a second jeep, blue
# (Crew, Level3DBtr.tint), on the 2D game's second player's keys and pad
# (ButtonMapping.second_player, saved in user://buttons2.cfg, which the game's
# Options -> "2p input" rebinds): the arrows, right Alt for the gun, right Ctrl
# for the rocket. It fires the classic way, the mouse being the first
# player's, and the arrows do not scroll the camera then. Each has its own
# lives, score, prisoners and weapon, on a HUD line of its own; the enemies go
# for the nearer one, the frame holds both (COOP_EDGE), the Chinook brings both
# in, the rescue helicopter takes both players' prisoners at once, and one out
# of lives is out until both are, when the stage starts again. What a round, a
# rocket or a blast of theirs destroys is the shooter's (Level3DGuns.acting).
extends Node3D

const LEVEL_PATH := "res://resources/3d/jackal_stage1.glb"
var level_path := LEVEL_PATH
const OCEAN_SHADER := preload("res://src/tools/level3d_ocean.gdshader")
const Btr := preload("res://src/tools/level3d_btr.gd")
const SCREEN_SHADER := preload("res://src/tools/level3d_screen.gdshader")

# From the Blender scene: J_Sun points along this (Blender axes), strength 3.
const SUN_DIRECTION_BLENDER := Vector3(0.4265, -0.5212, -0.7392)
const SUN_STRENGTH := 3.0
# Linear world colour and strength.
const WORLD_COLOR := Color(0.342, 0.552, 1.0)
const WORLD_STRENGTH := 0.12
# What a face in shadow keeps of a lit face's light, linear: the ambient, the
# only light there is in shadow. Blender's world, 0.12 of a blue sky, left the
# shadows at a fifth of the lit colour on screen, nearly black, and the black
# lines drawn across them lost; a cel shade is more like 55 to 60%, which is
# 0.3 linear. The world colour stays the background's.
const SHADE := 0.3

const SUN_GAIN_COMPATIBILITY := 0.85
const SUN_GAIN_FORWARD := 1.75
# The water's sun, given back what SHADE took of it (_replace_ocean).
# Measured, as the mean colour of the sea in the opening frame against the
# one before SHADE: Compatibility's sun share is not the water's. The glint
# needs no gain: the shader takes it at the sun's colour, not its energy.
const WATER_GAIN_COMPATIBILITY := 2.7
# The sea mask (_mark_sea): where the ocean's `open` has passed this, the
# water is the sea; its cells are this many metres square, and grown this many
# cells out over the shore, where `open` is nought again.
const SEA_OPEN := 0.3
const SEA_TEXEL := 1.0
const SEA_REACH := 5
# What is left of the sun once the ambient is SHADE, for a lit face to stay
# its colour. Forward+ adds the two as it should and leaves 1 - SHADE;
# Compatibility adds more of the ambient on a lit face than it does in
# shadow, and this is measured there: sand, palm leaves and the hangars'
# roofs back at their colours from before, 245,151,0 now 255,149,0.
const SUN_SHARE_COMPATIBILITY := 0.34
# And what more ambient adds to a lit face there, in the same units: the sun's
# share that gives up for each step of the shade above SHADE (_day_sun_energy),
# measured as SUN_SHARE_COMPATIBILITY was, on a lit grey.
const AMBIENT_ON_LIT_COMPATIBILITY := 1.5
# The top camera sits this far above the ground, which is as low as it can go
# over the tallest building; the shadow map only has to cover that depth.
const TOP_CAMERA_HEIGHT := 20.0
# Where the sea was cut off west when the level was built (level3d-pipeline.md,
# section 2), and the frame's west edge still; the water goes on past it.
const SEA_WEST := -27.0

# Where the BTR starts: on the beach at the south end, facing up the stage, with
# nothing within four metres -- the obstacle map's say, not the eye's. It used
# to start at x = 0, a turning circle away from a clump of four palms, so every
# first turn east ended on a trunk.
const START := Vector3(-7.0, 0.0, 27.0)
const START_HEADING := PI / 2.0


# START on the level being played: as far from its south end as from stage 1's.
static func start() -> Vector3:
	return START + Vector3(0.0, 0.0, Level3DMap.extra_px() * Level3DMap.PX)
# A ray from this high down to this low finds the top surface anywhere.
const RAY_TOP := 30.0
const RAY_BOTTOM := -5.0

const SCROLL_SPEED := 40.0
const ZOOM_STEP := 1.15

var camera: Camera3D
var sun: DirectionalLight3D
# The light preset (Level3DLighting): --light, or the settings' Light.
var lighting := Level3DLighting.Preset.DAY
var _fill: DirectionalLight3D
var _environment: Environment
var _water: ShaderMaterial
# The preset's grade, over the stage and under the pixels and the HUD.
var _grade: ColorRect
# The players, one or two (Crew). `btr`, `gun` and `launcher` are the first's:
# the mouse's and the --shot options', and the launcher whose craters the
# ground shows (Level3DLauncher.marks).
var crews: Array[Crew] = []
var btr: Level3DBtr
var gun: Level3DGun
var launcher: Level3DLauncher
var guns: Level3DGuns
var soldiers: Level3DSoldiers
var friends: Level3DFriends
var rescue: Level3DRescue
var tracks: Level3DTracks
var puffs: Level3DPuffs
var boats: Level3DBoats
var tanks: Level3DTanks
var boss: Level3DBoss
var map: Level3DMap
var chinook: Level3DChinook     # while it is flying the BTR in
var helicopter: Level3DChinook  # the same, until it has gone: it outlives the run
var level_aabb: AABB
var focus := Vector2.ZERO       # x, z the camera is centred on
var following := true
# What is left of the way from where the Chinook had the frame to the BTR
# (_process), and the time it takes to close most of it.
const CATCH_UP := 0.25
var _catch_up := Vector2.ZERO
var zoom := 1.0
var tilted := true      # Tab; the top view is the game's
# The Escape menu's (level3d_menu.gd): the camera, the look, the driving, the
# firing, the keys and the cheats. Saved only when the run is not a --shot.
var settings := Level3DSettings.new()
var _persist := false
var _menu: Level3DMenu
# The title screen (level3d_title.gd): at the start, and from the menu.
var _title: Level3DTitle
var _pixels: ColorRect
var _crt: ColorRect
# A click that closed the menu is not a round fired: the left button is not
# the gun's again until it has been let go of.
var _gun_locked := false

var _live := false
# The music's edge (_update_music): the boss armed.
var _saw_boss := false
const ENGINE_RISE := 2.5         # the mix's travel a second, 0 to 1
var _forced_aim = null  # --fire's or --rocket's target
var _hold_fire := false # --fire: the gun's trigger held throughout
# How much longer a right click waits to be a rocket (Crew.rocket_wanted); see
# _physics_process.
const ROCKET_WAIT := 0.8
var _strip := []        # --strip: frames, seconds apart, px square
var _kinds := {}        # body RID -> ground kind, see _add_collision
var _trunks := 0
var _markers: Array[MeshInstance3D] = []
var _marker_mesh: Mesh
var _marker_material: StandardMaterial3D


func _ready() -> void:
	# Before anything is added: every mesh from here on, the level's and every
	# unit's, spawned now or later, is lit in two tones (_toon) and gets its
	# contour from the engine (_engine_contour).
	var run_args := OS.get_cmdline_user_args()
	_persist = not (run_args.has("--shot") or run_args.has("--obstacle-map"))
	if _persist:
		settings.load_saved()
	Level3DMap.hard = settings.hard
	get_tree().node_added.connect(_toon)
	# First, so that everything added after it has something to be heard
	# through (Level3DAudio.play is a no-op until then).
	add_child(Level3DAudio.new())
	Level3DHull.creases = OS.get_cmdline_user_args().has("--engine-creases")
	Level3DHull.drawn = not OS.get_cmdline_user_args().has("--no-contour")
	Level3DFx.real_shadows = not OS.get_cmdline_user_args().has("--spots")
	if not OS.get_cmdline_user_args().has("--baked-contour"):
		get_tree().node_added.connect(_engine_contour)
	if run_args.has("--level"):
		level_path = run_args[run_args.find("--level") + 1]
	if run_args.has("--file"):
		Level3DMap.file = run_args[run_args.find("--file") + 1]
		Level3DMap.rows = int(Level3DIO.read_path(Level3DMap.file)["grid"]["height"])
	# The title screen first, which starts the run when a game is picked;
	# not for a --shot, nor for the level editor's Play, there to try the
	# level out. It is up before the stage is built: the stage is built under
	# it a little at a time (_breathe), the title's splash playing on, and a
	# game picked before it is done waits for it (Level3DTitle.game_ready).
	var titled := _persist and not run_args.has("--editor") and not run_args.has("--intro")
	if titled:
		_make_menu()
		_apply_settings()
		_show_title()
		await get_tree().process_frame
		_slicing = true
		_slice_from = Time.get_ticks_usec()
	var scene: PackedScene = load(level_path)
	if scene == null:
		push_error("Cannot load %s -- open the project in the editor once so it is imported" % level_path)
		return
	var level := scene.instantiate()
	await _breathe()
	add_child(level)
	await _breathe()
	_replace_ocean(level)
	# The level goes on past its edges, forest, beach and sea, for the tilted
	# camera to look over (jackal_level_edges.py); the frame stays where the
	# level was: at the map's end north, as the game's does at row 0, at the
	# sea's old edge west, and at the land's east, leaving out the strip past
	# it, Beyond_*, and the sea, which runs under that strip.
	level_aabb = _mesh_aabb(level, ["Beyond", "Ocean"])
	var corner := Vector3(SEA_WEST, level_aabb.position.y, maxf(level_aabb.position.z, Level3DMap.ORIGIN.y))
	level_aabb = AABB(corner, level_aabb.end - corner)
	# That was the hand-built level. One built from the level file
	# (tools/blender/build_level.py), which jackal_stage1.glb is now, has
	# ground out to the file's bounds, so its meshes cannot say where the
	# frame is: the file's frame, measured off the hand-built level as above,
	# does. The meshes are the fallback for a file without one.
	var frame: Array = Level3DIO.read_path(Level3DMap.level_path()).get("terrain", {}).get("frame", [])
	if frame.size() == 4:
		level_aabb = AABB(Vector3(frame[0], level_aabb.position.y, frame[1]),
				Vector3(float(frame[2]) - float(frame[0]), level_aabb.size.y, float(frame[3]) - float(frame[1])))
	_cast_both_sides_of_planes(level)
	_flat_ground_casts_nothing(level)
	await _breathe()
	await _add_collision(level, true)
	# After the collision, which is how it tells the water from the land.
	_mark_sea(level)
	await _breathe()
	_add_targets(level, false)
	await _breathe()
	# Last: it adds meshes of its own, which want no collision.
	_holed_ground(level)
	await _breathe()
	_add_destructibles()
	await _breathe()
	_add_marks(level)
	await _breathe()
	# After the contour and the shadows, whose materials it replaces.
	_add_wind(level)
	await _breathe()

	_add_environment()
	_add_lights()

	# The game's own mappings, as the game last saved them: the gun's turbo
	# switch, and the second player's keys and pad.
	_mapping.load_saved()
	_mapping_2 = ButtonMapping.second_player(_mapping)
	_mapping_2.load_saved()
	_make_hud()
	if titled:
		move_child(_title, -1)
		move_child(_menu, -1)
	await _breathe()
	_add_crew()
	await _breathe()
	_add_guns(level)
	await _breathe()
	_arm(crews[0])
	launcher.ground_materials = _ground_materials
	launcher.ground_materials.append(tracks.material())
	_make_markers()
	if not titled:
		_make_menu()
	add_child(KeySides.new())

	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	_apply_settings()

	# The level's collision exists from the next physics frame on; the BTR is
	# placed after it, or it would sit on nothing.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var args := OS.get_cmdline_user_args()
	var players := args.find("--players")
	# One player unless asked for two: the menu's game for two lasts the run.
	_set_players(int(args[players + 1]) if players >= 0 else 1)
	_place_crews()
	focus = _follow_point()
	_update_camera()
	_live = true
	_slicing = false

	if titled:
		# Over the HUD again, made since on the same layer, and the Escape
		# menu over the title, in the order _make_menu adds them after it.
		move_child(_title, -1)
		move_child(_menu, -1)
		_title.game_ready()
	else:
		# intro_song, IntroMapMode's: the start jingle running on into stage 1.
		Level3DAudio.play_music("intro")
		if args.has("--intro") or not (args.has("--shot") or args.has("--obstacle-map")):
			_start_intro()
		_start_flags()
	_screenshot_mode()


# Building the stage under the title (_ready): a step of it that has run
# past SLICE_BUDGET in this frame hands the frame back, so that the title's
# splash goes on playing while it is built, a frame lost here and there
# rather than 2.5 s at once.
const SLICE_BUDGET := 8000      # microseconds
var _slicing := false
var _slice_from := 0

func _breathe() -> void:
	if _slicing and Time.get_ticks_usec() - _slice_from > SLICE_BUDGET:
		await get_tree().process_frame
		_slice_from = Time.get_ticks_usec()


# The Chinook's run, from the top: Triggers.CHINOOK, which the stage fires on
# its first row. Nothing is the player's until it is over.
func _start_intro() -> void:
	if helicopter != null:
		helicopter.queue_free()
	chinook = Level3DChinook.new()
	helicopter = chinook
	chinook.left = func(): helicopter = null
	chinook.frame = _view_frame
	chinook.sun = sun
	chinook.ground = _ground_at
	chinook.map = map
	for c in crews:
		if not c.out:
			chinook.btrs.append(c.btr)
	chinook.dust = func(at: Vector3, across: Vector3, out: Vector3, size: float, count: int):
		puffs.cloud(at, across, out, size, count)
	chinook.enlarge = not tilted
	chinook.finished = func():
		chinook = null
		_catch_up = focus - _follow_point()
		following = true
		# Player.make_invincible.
		for c in crews:
			c.invincible = Player.INVINCIBLE_DELAY
			c.blink = 0
	add_child(chinook)
	following = true


# ----------------------------------------------------------------------------
# The players

# One player: the vehicle, its two weapons and what the game keeps for him --
# Player's counters, PlayerState's lives and score, and the prisoners and the
# weapon (`carrier`, Level3DFriends'). The first is driven by the settings'
# keys and the mouse; the second by the 2D game's second player (`input`).
class Crew:
	var index := 0
	var btr: Level3DBtr
	var gun: Level3DGun
	var launcher: Level3DLauncher
	var carrier := Level3DFriends.Carrier.new()
	var hud: Level3DHud
	var input: HumanInput       # the second player's; null for the first
	# Player.update's two counters, in ticks: while `respawning` the vehicle is
	# gone and nothing it does happens; while `invincible` rounds and mines
	# pass it by.
	var respawning := 0
	var invincible := 0
	var blink := 0
	# The spare lives, as Main.extra_lives.
	var lives := 0
	var score := 0
	# Out of lives while the other plays on (PlayerState.out): not driven,
	# drawn, aimed at or followed, until the stage starts again.
	var out := false
	# Player's fire_released, for the classic rocket button; how much longer a
	# press waits to be a rocket, driving free; the second player's rocket
	# button on the last tick, for its press.
	var fire_released := true
	var rocket_wanted := 0.0
	var rocket_held := false
	# Its engine, two loops on it mixed by speed (_update_engine_sound).
	var engine_level := 0.0
	# Rockets and grenades it has fired, for the rocket's hint (_hint_done).
	var rockets := 0
	# The weapon's level last shown, for the POWER UP over it (_show_state):
	# -1 before the first.
	var weapon_shown := -1


# Every key event to HumanInput.key_event, the Escape menu or not (it pauses
# the tree, and this goes on): the second player's weapons are right Alt and
# right Ctrl, which only the events tell from the left ones (Main._input). All
# let go of when the window loses the focus, which is when releases go missing.
class KeySides:
	extends Node

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		if event is InputEventKey:
			HumanInput.key_event(event)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			HumanInput.release_all()


# Main.button_mapping and button_mapping_2, as the game last saved them.
var _mapping := ButtonMapping.new()
var _mapping_2: ButtonMapping

# The second player's colours: Main.players_blue's turn of the green.
const BLUE_HUES := Vector3(80.0, 130.0, 100.0)
# The vehicle's lit olive (BTR_OliveLight), the colour the score and the points
# for a prisoner show in; the second's turned as its vehicle is.
const CREW_COLOUR := Color("5ca83e")

static func _crew_colour(index: int) -> Color:
	var colour := CREW_COLOUR
	if index > 0:
		colour.h = fposmod(colour.h * 360.0 + BLUE_HUES.z, 360.0) / 360.0
	return colour
# How near the frame's top and bottom either jeep may come with two of them,
# level metres: GameMode.COOP_EDGE.
const COOP_EDGE := GameMode.COOP_EDGE * Level3DMap.PX
# The second jeep's start beside the first, level metres: GameMode's
# COOP_SPAWN_SPREAD, to the east.
const COOP_SPREAD := GameMode.COOP_SPAWN_SPREAD * Level3DMap.PX


# A player, the next one: its vehicle, gun and launcher, wired to the stage
# once there is one (_arm), and its HUD line.
func _add_crew() -> Crew:
	var c := Crew.new()
	c.index = crews.size()
	c.lives = EXTRA_LIVES
	c.btr = Btr.new()
	c.btr.ground = _hull_ground_at
	add_child(c.btr)
	if c.index > 0:
		c.btr.tint(BLUE_HUES.x, BLUE_HUES.y, BLUE_HUES.z)
		c.input = HumanInput.new(_mapping_2)
		c.input.arrows = false
	Level3DAudio.attach_loop("btr_idle", c.btr)
	Level3DAudio.attach_loop("btr_drive", c.btr)
	c.gun = Level3DGun.new()
	c.gun.btr = c.btr
	c.gun.ground = _ground_at
	c.gun.surface = _surface_at
	c.gun.strike = _strike_at
	c.gun.dull = _dull_at
	c.gun.turbo = (_mapping if c.index == 0 else _mapping_2).turbo
	add_child(c.gun)
	c.launcher = Level3DLauncher.new()
	c.launcher.btr = c.btr
	c.launcher.ground = _ground_at
	c.launcher.surface = _surface_at
	c.launcher.strike = _strike_at
	if c.index > 0:
		c.launcher.marks = crews[0].launcher
	add_child(c.launcher)
	c.hud = Level3DHud.new()
	c.hud.lives_icon = "lives_2" if c.index > 0 else "lives"
	c.hud.colour = _crew_colour(c.index)
	c.hud.right = c.index > 0
	_hud.add_child(c.hud)
	crews.append(c)
	if c.index == 0:
		btr = c.btr
		gun = c.gun
		launcher = c.launcher
	return c


# One player or two: the second added, or taken away, for the next run.
func _set_players(count: int) -> void:
	count = clampi(count, 1, 2)
	while crews.size() < count:
		_arm(_add_crew())
	while crews.size() > count:
		var c: Crew = crews.pop_back()
		Level3DAudio.stop_loop(c.btr, "btr_idle")
		Level3DAudio.stop_loop(c.btr, "btr_drive")
		for node: Node in [c.btr, c.gun, c.launcher, c.hud]:
			node.queue_free()
	friends.carriers.clear()
	for c in crews:
		friends.carriers.append(c.carrier)
	tracks.sources = [tanks.track_contacts, boss.track_contacts]
	puffs.sources = [tanks.puffs, boss.puffs, boats.puffs]
	for c in crews:
		tracks.sources.append(c.btr.wheel_tracks)
		puffs.sources.append(c.btr.puffs)
	_apply_settings()
	_layout_hud()
	_show_state()


# Where the run starts: the first at start(), the second beside it.
func _place_crews() -> void:
	for c in crews:
		c.btr.place(start() + Vector3(COOP_SPREAD * c.index, 0.0, 0.0), START_HEADING)


# A player's weapons and vehicle wired to the stage's enemies, as _add_guns
# wires the enemies to each other. Every way its weapons kill says first that
# it is this player's doing (Level3DGuns.acting), for the points.
func _arm(c: Crew) -> void:
	c.btr.map = map
	var gun_of := c.gun
	var launcher_of := c.launcher
	# A round stops at the first enemy on its way, gun, soldier, boat or tank;
	# a missile kills the soldiers it passes and stops at a gun, a boat or a
	# tank.
	gun_of.intercept = func(from: Vector3, to: Vector3):
		return _nearest([guns.intercept(from, to, PlayerBullet.MARGIN),
				soldiers.intercept(from, to, PlayerBullet.MARGIN),
				boats.intercept(from, to, PlayerBullet.MARGIN),
				tanks.intercept(from, to, PlayerBullet.MARGIN),
				boss.intercept(from, to, PlayerBullet.MARGIN)])
	gun_of.struck = func(found: Dictionary):
		guns.acting = c
		if found.has("gun"):
			guns.bullet_attack(found.gun)
		elif found.has("boat"):
			boats.bullet_attack(found)
		elif found.has("tank"):
			tanks.bullet_attack(found)
		elif found.has("boss"):
			boss.bullet_attack(found)
		else:
			soldiers.bullet_attack(found)
	# Where the enemies' rounds end, the first jeep's gun's say what is seen.
	if c.index == 0:
		guns.landed = gun_of.landed
		guns.stopped = gun_of.stopped
		guns.impact = gun_of.impact
	launcher_of.intercept = func(from: Vector3, to: Vector3):
		guns.acting = c
		soldiers.sweep(from, to, PlayerMissile.MARGIN)
		return _nearest([guns.intercept(from, to, PlayerMissile.MARGIN, true),
				boats.intercept(from, to, PlayerMissile.MARGIN, true),
				tanks.intercept(from, to, PlayerMissile.MARGIN, true),
				boss.intercept(from, to, PlayerMissile.MARGIN, true)])
	launcher_of.struck = func(found: Dictionary):
		guns.acting = c
		if found.has("boat"):
			boats.attack(found)
		elif found.has("tank"):
			tanks.attack(found)
		elif found.has("boss"):
			boss.attack(found)
		else:
			guns.attack(found.gun)
	launcher_of.exploded = func(at: Vector3) -> bool:
		guns.acting = c
		return _on_exploded(at)
	launcher_of.traveled = func(at: Vector3, direction: Vector2):
		guns.acting = c
		guns.travel(at, direction)


# GameMode.target_player: the player nearest `from`, level x, z, of those in
# the game, one that is not respawning before one that is; the first when
# there is none.
func _target(from: Vector2) -> Crew:
	var best: Crew = null
	var best_d := INF
	for back in [false, true]:
		for c in crews:
			if c.out or (c.respawning > 0) != back:
				continue
			var d := from.distance_squared_to(Vector2(c.btr.position.x, c.btr.position.z))
			if d < best_d:
				best_d = d
				best = c
		if best != null:
			return best
	return crews[0]


# Who a kill's points go to: the player whose weapon did it, or the first.
func _credited() -> Crew:
	return guns.acting if guns.acting is Crew else crews[0]


# Another player still in the game than `c`.
func _other_in(c: Crew) -> bool:
	for other in crews:
		if other != c and not other.out:
			return true
	return false


# Layout px along the frame's bottom that the HUD's line covers: none with it
# at the top or off.
func _hud_bottom_inset() -> float:
	if crews.is_empty() or not settings.hud or settings.hud_corner != Level3DSettings.HudCorner.BOTTOM:
		return 0.0
	return crews[0].hud.line_height()


# _hud_bottom_inset in level metres, as the frame from straight above has it:
# the tilted one's bottom is nearer, so it covers a little less there.
func _hud_inset_metres() -> float:
	return _hud_bottom_inset() * _view_frame().size.x / Main.SCREEN_WIDTH


# Where the frame follows: the players in the game, between them. With two,
# half the HUD's line to the south of it, so that the middle of them is the
# middle of what the line leaves of the frame: with one the frame is not held
# to its edges, and stays as it was.
func _follow_point() -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for c in crews:
		if not c.out:
			total += Vector2(c.btr.position.x, c.btr.position.z)
			count += 1
	if count == 0:
		return Vector2(btr.position.x, btr.position.z)
	var shift := Vector2(0.0, _hud_inset_metres() * 0.5) if count > 1 else Vector2.ZERO
	return total / count + shift


# Two players: each held where the frame can still have the other, COOP_EDGE
# in from its top and bottom (Level3DBtr.z_limits) -- the frame follows the
# middle of them, so that is never further apart than its height less those,
# and less the HUD's line along the bottom, which _follow_point frames them
# above.
func _hold_crews() -> void:
	var span := maxf(_view_frame().size.y - 2.0 * COOP_EDGE - _hud_inset_metres(), 0.0)
	for c in crews:
		c.btr.z_limits = Vector2(-INF, INF)
		for other in crews:
			if other != c and not other.out and not c.out:
				c.btr.z_limits = Vector2(other.btr.position.z - span, other.btr.position.z + span)


static func _is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


# Blender Z-up to Godot Y-up, which is what the glTF exporter did to the level.
static func _from_blender(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y)


func _add_environment() -> void:
	_environment = Environment.new()
	# The shadow side's light, and all of it: grey by day, since the sky's
	# blue would be lost on the sand anyway, which has none to reflect; its
	# colour and strength are the light preset's (_apply_lighting).
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.background_mode = Environment.BG_COLOR
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)


func _add_lights() -> void:
	sun = DirectionalLight3D.new()
	add_child(sun)
	sun.shadow_enabled = true
	# A shadow's edge is a line, not a blur: no filtering, docs/cel-shading.md.
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	# Without the blur the map's texels show as steps along it; twice the
	# default halves them.
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	# The fill (Level3DLighting): what stands up, lit on its shaded side.
	_fill = DirectionalLight3D.new()
	_fill.shadow_enabled = false
	add_child(_fill)
	_apply_lighting()

	# No lamp. The Blender scene's default point light is still in it, and
	# was rendered with here as a faint warm spot over the start area; but a
	# point light falls off with distance, which is a gradient across the sand,
	# and the two-tone light (_toon) is there to have none.


# The sun's energy for white light under an ambient of `shade`: the day's,
# SHADE, is what the HUD's icons keep whatever the preset (_render_icons).
func _day_sun_energy(shade := SHADE) -> float:
	# The two renderers disagree by about a factor of two, so the gain is
	# measured rather than derived: sand at the start of the stage matched
	# against the same frame rendered in Blender.
	var gain := SUN_GAIN_COMPATIBILITY if _is_compatibility() else SUN_GAIN_FORWARD
	# Measured with Lambert light, under which the sand took the sun times
	# N.L, the sun's height; _toon's lit side takes all of it, so the same
	# sand wants the sun that much weaker. The day's height, whatever the
	# preset's: it is part of the calibration, and the lit side takes all of
	# a lower sun too.
	gain *= -SUN_DIRECTION_BLENDER.z
	# At that gain a lit face takes about its own colour, which the ambient's
	# SHADE is now part of, so the sun gives up that much -- and what a
	# lighter shade adds to a lit face on top of that (AMBIENT_ON_LIT).
	if _is_compatibility():
		gain *= SUN_SHARE_COMPATIBILITY - AMBIENT_ON_LIT_COMPATIBILITY * (shade - SHADE)
	else:
		gain *= 1.0 - shade
	return SUN_STRENGTH / PI * gain


# The light preset (Level3DLighting) on the sun, the fill, the ambient, the
# background, the water and the grade: at the start, and again whenever the
# menu picks another. Every colour's energy is held to the day's
# brightness on a grey (Level3DLighting.keep), times the exposure; a lighter
# shade takes the sun down by as much as it adds to a lit face, so that a lit
# grey stays where it was.
func _apply_lighting() -> void:
	var spec := Level3DLighting.spec(lighting)
	if _grade != null:
		var grade := _grade.material as ShaderMaterial
		for key in ["shade_tint", "light_tint"]:
			var tint: Color = spec[key]
			grade.set_shader_parameter(key, Vector3(tint.r, tint.g, tint.b))
		for key in ["shade_amount", "light_amount"]:
			grade.set_shader_parameter(key, spec[key])
		_grade.visible = spec["shade_amount"] > 0.0 or spec["light_amount"] > 0.0
	if sun == null:
		return
	var exposure: float = spec["exposure"]
	var shade: float = spec["shade"]
	var direction := Level3DLighting.sun_direction(spec, SUN_DIRECTION_BLENDER)
	sun.look_at_from_position(Vector3.ZERO, _from_blender(direction).normalized(), Vector3.FORWARD)
	var sun_colour: Color = spec["sun"]
	sun.light_color = sun_colour
	var hold: float = spec["hold"]
	sun.light_energy = _day_sun_energy(shade) * Level3DLighting.keep(sun_colour, Level3DLighting.GREY, hold) * exposure

	var fill_direction := Level3DLighting.fill_direction(SUN_DIRECTION_BLENDER)
	var up := Vector3.UP if absf(fill_direction.z) < 0.99 else Vector3.FORWARD
	_fill.look_at_from_position(Vector3.ZERO, _from_blender(fill_direction).normalized(), up)
	_fill.light_color = spec["fill_colour"]
	_fill.light_energy = _day_sun_energy() * float(spec["fill"]) * exposure
	_fill.visible = float(spec["fill"]) > 0.0

	var ambient: Color = spec["ambient"]
	_environment.ambient_light_color = ambient
	_environment.ambient_light_energy = shade * Level3DLighting.keep(ambient, Level3DLighting.GREY, hold) * exposure
	var background = spec["background"]
	if background == null:
		background = (WORLD_COLOR * WORLD_STRENGTH).linear_to_srgb()
	_environment.background_color = background

	if _water == null:
		return
	# The sun _add_lights weakened for the two-tone light, given back to the
	# water, which is still lit smoothly (Burley, as Godot's own diffuse): all
	# of it under Forward+, where the water is as bright as it was at 1 / N.L;
	# Compatibility's, measured the same way, needs less. And what SHADE took
	# of the sun on top of that. The ambient the water takes is not SHADE's
	# grey but the Blender world it was calibrated under, which the shader adds
	# for itself.
	var water_gain := 1.0 / -SUN_DIRECTION_BLENDER.z / (1.0 - SHADE)
	if _is_compatibility():
		water_gain = WATER_GAIN_COMPATIBILITY
	# Lambert, so a lower sun lights it less: given back, and what a lighter
	# shade took off the sun. Its colour is not: under a warm sun the sea
	# darkens (Level3DLighting).
	water_gain *= -SUN_DIRECTION_BLENDER.z / -direction.z
	water_gain *= _day_sun_energy() / _day_sun_energy(shade)
	_water.set_shader_parameter("sun_gain", water_gain)
	var sky = spec["sky"]
	if sky == null:
		sky = Vector3(WORLD_COLOR.r, WORLD_COLOR.g, WORLD_COLOR.b) * WORLD_STRENGTH
	_water.set_shader_parameter("sky", sky)
	# Its shadows lifted as the land's are, or they are black: the sun is all
	# the light the water has.
	_water.set_shader_parameter("shade", shade)


func _replace_ocean(level: Node) -> void:
	var ocean := level.find_child("Ocean", true, false) as MeshInstance3D
	if ocean == null:
		push_warning("No Ocean node in %s" % level_path)
		return
	var water := ShaderMaterial.new()
	water.shader = OCEAN_SHADER
	# Its light, the sun's gain and the sky, is the light preset's
	# (_apply_lighting), set when the sun is made.
	_water = water
	ocean.material_override = water
	# The water is drawn in the transparent pass, because it reads the screen;
	# it casts nothing either way.
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# Which of the water is the sea rather than the river, for the ocean shader's
# surf, which comes in off the sea and not down the river: its sea_mask and
# sea_box. Blender's `open`, the ocean's green vertex colour, only ever passes
# SEA_OPEN out at sea -- the river is never that far from a bank -- but it is
# nought along every shore, the sea's as well, which is where the surf is. So
# the cells where it passes are grown by SEA_REACH, out over that band.
#
# Only where the water is on top. The ocean runs on under the land, and
# `open`, a distance to the nearest shore with no side to it, passes SEA_OPEN
# under every stretch of land wide enough: grown from there, it covered the
# river from both banks. And only the open water that reaches the west edge,
# the sea's: the river opens out too, where it runs off the map to the east.
func _mark_sea(level: Node) -> void:
	var ocean := level.find_child("Ocean", true, false) as MeshInstance3D
	if ocean == null or not ocean.material_override is ShaderMaterial:
		return
	var to_world := ocean.global_transform
	var open: Array[Vector2] = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in ocean.mesh.get_surface_count():
		var arrays := ocean.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in vertices.size():
			var at := to_world * vertices[i]
			var xz := Vector2(at.x, at.z)
			lo = lo.min(xz)
			hi = hi.max(xz)
			if i < colours.size() and colours[i].g >= SEA_OPEN:
				open.append(xz)
	var size := Vector2i(((hi - lo) / SEA_TEXEL).floor()) + Vector2i.ONE
	var cells := PackedByteArray()
	cells.resize(size.x * size.y)
	for xz in open:
		var cell := Vector2i(((xz - lo) / SEA_TEXEL).floor())
		cells[cell.y * size.x + cell.x] = 255
	for y in size.y:
		for x in size.x:
			if cells[y * size.x + x] == 0:
				continue
			var middle := lo + (Vector2(x, y) + Vector2(0.5, 0.5)) * SEA_TEXEL
			if _ground_at(middle.x, middle.y).kind != "water":
				cells[y * size.x + x] = 0
	cells = _west_of(cells, size)
	cells = _grow(cells, size, Vector2i(1, 0), SEA_REACH)
	cells = _grow(cells, size, Vector2i(0, 1), SEA_REACH)
	var water := ocean.material_override as ShaderMaterial
	water.set_shader_parameter("sea_mask", ImageTexture.create_from_image(
			Image.create_from_data(size.x, size.y, false, Image.FORMAT_L8, cells)))
	water.set_shader_parameter("sea_box", Vector4(lo.x, lo.y, size.x * SEA_TEXEL, size.y * SEA_TEXEL))


# `cells`, size.x across, with only the set cells joined to its west column
# left set, side to side or corner to corner.
static func _west_of(cells: PackedByteArray, size: Vector2i) -> PackedByteArray:
	var kept := PackedByteArray()
	kept.resize(cells.size())
	var todo: Array[Vector2i] = []
	for y in size.y:
		if cells[y * size.x] != 0:
			kept[y * size.x] = 255
			todo.append(Vector2i(0, y))
	while not todo.is_empty():
		var at: Vector2i = todo.pop_back()
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := at + Vector2i(dx, dy)
				if c.x < 0 or c.x >= size.x or c.y < 0 or c.y >= size.y:
					continue
				var i := c.y * size.x + c.x
				if cells[i] != 0 and kept[i] == 0:
					kept[i] = 255
					todo.append(c)
	return kept


# `cells`, size.x across, with every set cell spread `reach` cells either way
# along `axis`: once along each axis is a square of 2 * reach + 1.
static func _grow(cells: PackedByteArray, size: Vector2i, axis: Vector2i, reach: int) -> PackedByteArray:
	var grown := PackedByteArray()
	grown.resize(cells.size())
	for y in size.y:
		for x in size.x:
			if cells[y * size.x + x] == 0:
				continue
			for k in range(-reach, reach + 1):
				var c := Vector2i(x, y) + axis * k
				if c.x >= 0 and c.x < size.x and c.y >= 0 and c.y < size.y:
					grown[c.y * size.x + c.x] = 255
	return grown


# Two-tone light, docs/cel-shading.md, section 5: a face is lit or it is not,
# with no gradient between. DIFFUSE_TOON steps N.L at zero, over a band as
# wide as the roughness, so the roughness goes down to TOON_EDGE -- at the
# glb's 0.5 to 1 the step is as soft as Lambert. The low roughness would turn
# every sunlit face into a highlight, the sand included (the camera looks
# down, the half vector is 20 degrees off the ground's normal), so there is no
# specular and no reflection -- the background's, which at that roughness is
# a sheen on every face -- and no metal, which trades diffuse for reflection.
#
# Not the contour's material, black whatever the light; not what glows, the
# flashes, the fire and the lamps; not a ShaderMaterial, the water and the
# boat's wake, whose light is their shaders' own. Materials are the glbs'
# shared resources, so each is changed once, and the copies the soldiers and
# prisoners make of theirs to blink are made after this and keep it.
const TOON_EDGE := 0.02

func _toon(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null:
		return
	var materials: Array[Material] = [mesh_instance.material_override]
	if mesh_instance.mesh != null:
		for surface in mesh_instance.mesh.get_surface_count():
			materials.append(mesh_instance.mesh.surface_get_material(surface))
			materials.append(mesh_instance.get_surface_override_material(surface))
	for material in materials:
		var base := material as BaseMaterial3D
		if base == null or base.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON \
				or base.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL \
				or base.emission_enabled or base.resource_name.ends_with("Contour"):
			continue
		base.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		base.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		base.roughness = TOON_EDGE
		base.metallic = 0.0
		base.metallic_specular = 0.0


# The contour, grown by a shader in place of the Solidify's shell the glbs
# carry (Level3DHull, docs/cel-shading.md, section 5). --baked-contour keeps
# the shell, to compare the two; --no-contour draws neither.
func _engine_contour(node: Node) -> void:
	if node is MeshInstance3D:
		Level3DHull.apply(node)


# The palms and the trees sway, and the blasts and the rounds throw them about
# (level3d_wind.gd): whatever has a trunk, smooth or stepped, G toggling.
func _add_wind(level: Node) -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--no-wind"):
		return
	for node in level.find_children("*", "MeshInstance3D", true, false):
		Level3DWind.apply(node)
	Level3DWind.set_stepped(args.has("--wind-steps"))


# What the rockets and the rounds mark where they strike (Level3DMarks): the
# walls, the bunkers, the sandbags and the rocks of the stage, and the
# buildings, every part that can be hit -- the ruins' walls as well as the
# intact ones, so that the soot of a rocket that brought a barracks down is
# on what is left of it.
func _add_marks(level: Node) -> void:
	for node in level.find_children("*", "MeshInstance3D", true, false):
		var object_name := String(node.name)
		if _kind_of(object_name) == "wall" \
				or TARGET_NAMES.any(func(prefix): return object_name.begins_with(prefix)):
			Level3DMarks.apply(node)
	for building in destructibles:
		for node in destructibles[building].root.find_children("*", "MeshInstance3D", true, false):
			if not NOT_TARGET_PARTS.any(func(part): return node.name.contains(part)):
				Level3DMarks.apply(node)


# Palm fronds and the like are single planes, and Compatibility culls front
# faces in the shadow pass, which drops every plane that faces the sun -- their
# shadows vanish unless both sides cast. Only for those, though: the ground
# casting both ways shadows itself and comes out dark and striped.
#
# Which those are is the foliage's materials to say. It used to be any small
# mesh with a double-sided material, but Blender exports every material
# double-sided, so that took in the bunkers, the rocks and every building --
# and a solid casting both ways shadows itself as the ground did: the hangars'
# curved roofs came out striped and cut into dark wedges, more or less as the
# camera, and the shadow map with it, moved. A solid casts its whole
# silhouette from one side of its faces, provided they are all wound outward.
# The hangars' were not -- eight of ten faces of each wound inward, all of
# the ruined shell -- and double-sided casting had been hiding it; they are
# wound outward in the stage file now.
const FOLIAGE_MATERIALS: Array[String] = ["Frond", "Leaf"]

func _cast_both_sides_of_planes(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null and material.cull_mode == BaseMaterial3D.CULL_DISABLED \
					and FOLIAGE_MATERIALS.any(func(part): return material.resource_name.contains(part)):
				mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
				break


# The ground, drawn by level3d_ground.gdshader rather than by the glb's
# materials, so that the craters are holes in it (level3d_holes.gdshaderinc)
# and the rockets' scorches lie on it (level3d_scorch.gdshaderinc): every
# surface in one of GROUND_MATERIALS, one shader material to each, taking its
# colour. What is painted on the ground has to let the holes through as well,
# or it would lie over them in the air: the beach's band lines and the
# hangars' pads' dashes, in J_Black. And the hard ground (HARD_NAMES), all of
# it, which is where the scorches mostly are, and where a building's crater
# can reach -- a hangar's lies half on its pad -- with its contour holed too
# (level3d_ground_contour.gdshader). The launcher is told of all of them
# (Level3DLauncher.ground_materials), and the tyre marks'.
const GROUND_MATERIALS: Array[String] = ["J_Sand", "J_BeachBrown", "J_BeachGreen", "J_ForestFloor",
		"J_Earth", "J_RiverBed"]
const PAINTED_ON_GROUND: Array[String] = ["Shore_Lines", "HangarPad_Dash"]
const GROUND_SHADER := preload("res://src/tools/level3d_ground.gdshader")
const GROUND_CONTOUR_SHADER := preload("res://src/tools/level3d_ground_contour.gdshader")
var _ground_materials: Array[ShaderMaterial] = []

#
# A shader that discards is drawn into the shadow map another way than an
# opaque one, and the ground that casts -- the pieces with the river's banks
# in them -- came out shadowing itself, rippled with acne all over the north
# of the stage. So what is holed casts nothing, and a copy of it with the
# glb's own materials, seen by nothing but the sun, casts in its place: the
# shadows as they were. They have no holes: a crater's bowl in one of those
# pieces -- the green beach band, the forest's north-west, the river beyond
# the east -- lies in its shadow, darker than one in the sand.
func _holed_ground(root: Node) -> void:
	var made := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var painted := PAINTED_ON_GROUND.any(func(prefix): return mesh_instance.name.begins_with(prefix))
		var hard := _kind_of(mesh_instance.name) == "hard"
		var holed_any := false
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface)
			# The contour is the engine's hull (_engine_contour); the glb's own
			# shell, under --baked-contour, is left whole.
			var hull := Level3DHull.is_hull(material)
			if not (material is BaseMaterial3D or hull):
				continue
			var called := material.resource_name
			if hull and not hard or called.ends_with("Contour") and not hull:
				continue
			if not (called in GROUND_MATERIALS or painted and called == "J_Black" or hard):
				continue
			if not made.has(called):
				var holed := ShaderMaterial.new()
				if hull:
					holed.shader = GROUND_CONTOUR_SHADER
					holed.set_shader_parameter("pixels", Level3DHull.PIXELS)
				else:
					holed.shader = GROUND_SHADER
					holed.set_shader_parameter("albedo", (material as BaseMaterial3D).albedo_color)
				made[called] = holed
				_ground_materials.append(holed)
			mesh_instance.set_surface_override_material(surface, made[called])
			holed_any = true
		if holed_any and mesh_instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			var caster := MeshInstance3D.new()
			caster.mesh = mesh_instance.mesh
			caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			mesh_instance.add_child(caster)
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# The level's flat ground casts no shadow. A flat plane has nothing to shadow
# but itself, and does even that badly where it meets another: the stage is
# cut into 30 m pieces, some wound up and some down (Terrain_North to _North3
# face down, Sand and Terrain_North4 up), and along the edge between a piece
# that casts and one that does not the caster's edge left a dark line across
# the whole level -- at z = -105 and at z = -15. The pieces with a drop in them
# (the river's banks) are not flat and still cast.
#
# Nor does the slab under it all, Land_Base and Land_Base_North. It is buried
# -- Land_Base's top is 1 cm under the sand -- so it has nothing to shadow, but
# the edge of its shadow came up through the bias as a thin dashed line along
# the one seam it ends at, z = -15, across sand, beach and all.
#
# Nor do the black lines along the beach's bands, Shore_Lines (jackal_cel.py,
# shore_lines): 3 mm over the ground, and not flat by FLAT only because the
# green band slopes 4 cm to the cliff.
const FLAT := 0.02

func _flat_ground_casts_nothing(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var box := mesh_instance.get_aabb()
		if box.size.x * box.size.z > 25.0 and box.size.y <= FLAT \
				or mesh_instance.name.begins_with("Land_Base") 				or mesh_instance.name == "Shore_Lines":
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# The scene's collision, decided by what each object of the level is -- its
# Blender name -- rather than by how tall it is. It is not what stops anything
# any more: the BTR, its rounds and its rockets all go by the game's grid, in
# both modes (level3d_btr.gd, level3d_gun.gd, level3d_rocket.gd). It is what
# the hull sits on, and where a round or a rocket is seen to strike: how high,
# and on what.
#
# Two layers, for two kinds of question. The ground layer is what a downward
# ray finds: its height, and which kind it is -- the sea, the forest floor
# (the forest is the eight Forest_Floor patches its 3678 trees stand on, 98% of
# them; a tree is a crown, not something to hit), a wall, hard ground or
# plain ground. The solid layer is what stands up out of it: walls, and a
# cylinder round every palm trunk, which a round aimed past the palm's crown
# should still meet.
const GROUND_LAYER := 1
const SOLID_LAYER := 2
# A third, for the gun only: what stops a round but not the BTR -- bunkers,
# sandbags, rocks and the buildings that can be blown up. Kind "building".
const TARGET_LAYER := 4
const TARGET_NAMES: Array[String] = ["Bunker", "Sandbag", "Rock"]
# A fourth, for the hull only: the ramp over a bunker whose gun is gone
# (_add_bunker_ramp). Kind "ruin".
const RAMP_LAYER := 8
# The parts of a destruction that are not there to be hit: the blast itself and
# what lies flat or flies.
const NOT_TARGET_PARTS: Array[String] = ["Blast_", "Flash", "Smoke", "Shard", "Debris", "Soot"]
const GROUND_NAMES: Array[String] = ["Land_Base", "Beach", "Cliff", "Skirt", "Terrain"]
# What is built on the ground and flat -- concrete, plates, paint -- which a
# rocket scorches rather than digs into (Level3DLauncher._scorch) and a round
# chips rather than kicks up. The hangars' pads had no collision, and a
# rocket on one dug its crater in the sand under it, the pad over the hole;
# their doors stand up, and are not ground.
const HARD_NAMES: Array[String] = ["Bridge", "Helipad", "HangarPad", "Gate_Sill"]
const NOT_HARD_NAMES: Array[String] = ["HangarPad_Door"]
const WALL_NAMES: Array[String] = ["Wall", "Merlon", "GatePost", "Gate_"]
# What the gate leaves behind that is not a wall: the rubble, the soot and the
# blast itself. The stubs at either side are.
const NOT_WALL_NAMES: Array[String] = ["Gate_Debris", "Gate_Soot", "Gate_Flash",
		"Gate_Smoke", "Gate_Shard"]
# A trunk is solid up to about the BTR's roof; above that it leans into the
# crown, which the hull passes under.
const TRUNK_REACH := 1.2
const TRUNK_FOOT := 0.4


static func _kind_of(object_name: String) -> String:
	if object_name.begins_with("Ocean"):
		return "water"
	if object_name.begins_with("Forest_Floor"):
		return "forest"
	if object_name.begins_with("Palm"):
		return "trunk"
	if object_name == "Sand":
		return "ground"     # not a prefix: Sandbag is not ground
	if HARD_NAMES.any(func(prefix): return object_name.begins_with(prefix)):
		return "" if NOT_HARD_NAMES.any(func(prefix): return object_name.begins_with(prefix)) else "hard"
	for prefix in GROUND_NAMES:
		if object_name.begins_with(prefix):
			return "ground"
	for prefix in NOT_WALL_NAMES:
		if object_name.begins_with(prefix):
			return ""
	for prefix in WALL_NAMES:
		if object_name.begins_with(prefix):
			return "wall"
	return ""


# `sliced`: building the stage under the title (_breathe), handing the frame
# back between pieces.
func _add_collision(root: Node, sliced := false) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var kind := _kind_of(mesh_instance.name)
		if kind == "":
			continue
		if kind == "trunk":
			_add_trunk(mesh_instance)
			continue
		var body := StaticBody3D.new()
		body.collision_layer = GROUND_LAYER | (SOLID_LAYER if kind == "wall" else 0)
		mesh_instance.add_child(body)
		_kinds[body.get_rid()] = kind
		await _add_trimesh(body, mesh_instance.mesh, sliced)


# What MeshInstance3D.create_trimesh_collision makes, its body given: the
# mesh's triangles as concave shapes, but in pieces of at most COLLISION_PIECE
# triangles rather than one. One is the same to a ray; but the sea is 430,000
# triangles, nine in ten of the level's, and as one shape it was 0.7 s in a
# frame, the tree of its triangles and its place in the physics space, where
# in pieces it is 0.27 s, which the title can be left to play through.
const COLLISION_PIECE := 8000

func _add_trimesh(body: StaticBody3D, mesh: Mesh, sliced: bool) -> void:
	for surface in mesh.get_surface_count():
		if mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
				else PackedInt32Array()
		var corners := indices.size() if not indices.is_empty() else vertices.size()
		var from := 0
		while from < corners:
			var count := mini(COLLISION_PIECE * 3, corners - from)
			var faces := PackedVector3Array()
			faces.resize(count)
			if indices.is_empty():
				faces = vertices.slice(from, from + count)
			else:
				for i in count:
					faces[i] = vertices[indices[from + i]]
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(faces)
			# Both sides: the northern terrain's faces are wound downwards,
			# which its double-sided material hides from the eye and a
			# one-sided shape does not -- the ray went through the land and
			# found the sea under it.
			shape.backface_collision = true
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
			from += count
			if sliced:
				await _breathe()


# A cylinder round the bottom of the trunk: the trunk surface's own vertices
# below TRUNK_REACH, measured rather than assumed, because palms lean.
func _add_trunk(palm: MeshInstance3D) -> void:
	var trunk := PackedVector3Array()
	var base := INF
	for surface in palm.mesh.get_surface_count():
		var material := palm.mesh.surface_get_material(surface)
		if material == null or not material.resource_name.contains("Trunk"):
			continue
		var vertices: PackedVector3Array = palm.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for v in vertices:
			var w := palm.global_transform * v
			base = minf(base, w.y)
			trunk.append(w)
	if trunk.is_empty():
		push_warning("%s has no trunk surface; it will not stop the BTR" % palm.name)
		return
	# Measured at the foot, not over the whole reach: a leaning trunk's lower
	# metre spans half a metre sideways, and a circle round all of it is a
	# post twice as thick as the one on screen.
	var low := PackedVector2Array()
	for w in trunk:
		if w.y < base + TRUNK_FOOT:
			low.append(Vector2(w.x, w.z))
	var box := Rect2(low[0], Vector2.ZERO)
	for p in low:
		box = box.expand(p)
	var shape := CylinderShape3D.new()
	shape.radius = maxf(box.size.x, box.size.y) * 0.5
	shape.height = TRUNK_REACH
	var body := StaticBody3D.new()
	body.collision_layer = SOLID_LAYER
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	var centre := box.get_center()
	body.global_position = Vector3(centre.x, base + TRUNK_REACH * 0.5, centre.y)
	_kinds[body.get_rid()] = "trunk"
	_trunks += 1


# The target layer, on every mesh under `root` that the gun should stop at and
# the BTR need not: named in TARGET_NAMES, or -- `all` -- any part with no
# other kind that is not a piece of the blast.
func _add_targets(root: Node, all: bool) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var object_name := String(mesh_instance.name)
		if _kind_of(object_name) != "":
			continue
		var wanted := TARGET_NAMES.any(func(prefix): return object_name.begins_with(prefix))
		if all:
			wanted = not NOT_TARGET_PARTS.any(func(part): return object_name.contains(part))
		if not wanted:
			continue
		mesh_instance.create_trimesh_collision()
		for child in mesh_instance.get_children():
			if child is StaticBody3D:
				child.collision_layer = TARGET_LAYER
				_kinds[child.get_rid()] = "building"


# The top of whatever stands at x, z -- a wall, a trunk, a building or the
# ground -- and which kind it is: where a round or a rocket the grid has
# stopped is seen to strike (level3d_gun.gd, level3d_rocket.gd).
func _surface_at(x: float, z: float) -> Dictionary:
	return _ground_at(x, z, GROUND_LAYER | SOLID_LAYER | TARGET_LAYER)


# The top of the ground layer at x, z, and which kind it is.
func _ground_at(x: float, z: float, mask := GROUND_LAYER) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, RAY_TOP, z), Vector3(x, RAY_BOTTOM, z),
			mask)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {"height": 0.0, "kind": "", "hit": false}
	return {"height": hit.position.y, "kind": _kinds.get(hit.rid, "ground"), "hit": true}


# Where a round or a rocket that stopped at `at`, going `travel`, is seen to
# strike, for the mark it leaves (Level3DMarks): the grid stops it anywhere in
# a solid tile, which is often inside the wall or the rock drawn on it, or in
# front of it, and a mark there would lie on nothing. {"hit", "position",
# "normal", "kind", "colour"}: on the face it flew into, level, from
# STRIKE_BACK short of `at` to as far past it; on the top, if it came down on
# one or finds no face -- a round aimed over a low rock stops above it.
# `colour` is the struck surface's, for its rubble.
const STRIKE_BACK := 1.0
const ON_TOP := 0.02

func _strike_at(at: Vector3, travel: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var flat := Vector3(travel.x, 0.0, travel.z).normalized()
	var hit := {}
	var top := _surface_at(at.x, at.z)
	if flat != Vector3.ZERO and not (top.hit and at.y >= top.height - ON_TOP):
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(at - flat * STRIKE_BACK,
				at + flat * STRIKE_BACK, SOLID_LAYER | TARGET_LAYER))
	if hit.is_empty():
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * STRIKE_BACK,
				at + Vector3.DOWN * STRIKE_BACK, GROUND_LAYER | SOLID_LAYER | TARGET_LAYER))
	if hit.is_empty():
		return {"hit": false}
	var colour := Color.GRAY
	var mesh_instance := (hit.collider as Node).get_parent() as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		var material := mesh_instance.mesh.surface_get_material(0) as BaseMaterial3D
		if material != null:
			colour = material.albedo_color
	return {"hit": true, "position": hit.position, "normal": hit.normal,
			"kind": _kinds.get(hit.rid, "ground"), "colour": colour}


# Whether a round that stopped at `at`, flying `travel`, struck what only a
# rocket or a bomb breaks open, still standing: a POW hut or house, or a gate
# (Level3DGun.dull). Either its model, DULL_MARGIN round its footprint, or a
# solid cell its group opens: the grid stops a round in front of the gate's
# leaves, on its frame, which is the wall's. The cell is looked for where the
# round struck and half a tile on, since it stops on the face, not in it.
const DULL_MARGIN := 0.3
var _dull_cells := {}           # Vector2i map cell -> the destructible its group opens

func _dull_at(at: Vector3, travel: Vector3) -> bool:
	for building in destructibles:
		var entry: Dictionary = destructibles[building]
		if entry.destroyed or not entry.has("footprint"):
			continue
		var kind: String = entry.kind
		if kind != "Gate" and not Level3DFriends.HUT_KINDS.has(kind) and not Level3DFriends.HOUSE_KINDS.has(kind):
			continue
		if (entry.footprint as Rect2).grow(DULL_MARGIN).has_point(Vector2(at.x, at.z)):
			_thud = true
			return true
	var flat := Vector3(travel.x, 0.0, travel.z).normalized()
	for k in 2:
		var p := at + flat * (k * 16.0 * Level3DMap.PX)
		var m := Level3DMap.to_map(Vector2(p.x, p.z))
		var building = _dull_cells.get(Vector2i(int(m.x) >> 5, int(m.y) >> 5))
		if building != null and not destructibles[building].destroyed and map.is_missile_target(m.x, m.y):
			_thud = true
			return true
	return false


# What the hull sits on: the ground, and the ramps over the bunkers that have
# lost their guns. Nothing else asks for the ramps -- a round, a crater or a
# soldier goes by the ground as it is. And the craters the rockets and the
# buildings have left, their rims and bowls (Level3DLauncher.crater_height),
# which the hull's five samples of the ground turn into its pitch, roll and
# sinking.
func _hull_ground_at(x: float, z: float) -> Dictionary:
	return _with_craters(_ground_at(x, z, GROUND_LAYER | RAMP_LAYER), x, z)


# What the soldiers and the prisoners walk on: the ground and the craters in
# it, so that they go down into a hole rather than across it on nothing.
func _walker_ground_at(x: float, z: float) -> Dictionary:
	return _with_craters(_ground_at(x, z), x, z)


func _with_craters(there: Dictionary, x: float, z: float) -> Dictionary:
	if there.hit and there.kind != "water" and launcher != null:
		# Apart as well, so that the hull can tell a crater's slope from a
		# wall's edge (Level3DBtr._settle).
		there.crater = launcher.crater_height(x, z)
		there.height += there.crater
	return there


# Whether a box at `pose` overlaps anything on the solid layer.
func _solid_at(pose: Transform3D, half: Vector3) -> bool:
	var shape := BoxShape3D.new()
	shape.size = half * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = pose
	query.collision_mask = SOLID_LAYER
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# The buildings that can be blown up are not in the stage file: each is its own
# jackal_dest_<name>.glb, from export_destructibles() in the stage's Blender
# file, holding all three of its states -- intact, the blast, the ruins -- and
# one animation between them. glTF has no visibility, so the export folds it into
# the scale: whatever is hidden at a moment is shrunk to nothing then. Frame 0 of
# the animation is the intact building and its last frame the ruins, and the
# building is destroyed by playing it.
#
# Collision rides along. Each mesh gets its body as the stage's do, as a child,
# so a body follows its mesh's animated transform: the gate's leaves stop the
# BTR until they shrink away, and the stubs left at either side start to when
# they appear.
const DESTRUCTIBLE_NAMES: Array[String] = ["Barracks", "BarracksN", "BarracksN2",
		"BarracksN3", "Hangar_E", "Hangar_N", "Hangar_W", "Gate"]
const DESTRUCTIBLE_PATH := "res://resources/3d/jackal_dest_%s.glb"
const DESTRUCTION_ANIMATION := "Scene"
# Longer than any destruction animation (2.6 s).
const DESTRUCTION_SETTLE := 3.0

# name -> {root, player, centre, destroyed, bodies, footprint}; centre is
# where the flash goes off, footprint the intact building's Rect2 in x, z.
var destructibles := {}


# The buildings that are blown up, each {"name" (what destructibles and
# --destroy call it), "kind" (its jackal_dest_<kind>.glb), "move" (from where
# stage 1 has it), "group" (the destruction group a gate opens, or -1)}.
# Stage 1 has all of DESTRUCTIBLE_NAMES where they are; another level has one
# for every object whose asset the catalogue calls destructible -- a gate for
# every Gate object (the destructible part of it: the builder builds its
# frame), a barracks or a hangar for every Barracks* or Hangar one -- turned
# and moved from the catalogue's pivot, where stage 1 has it, to the object's
# place, and named by the object's id. Every gate opens the group of
# the GATE entity its object belongs to, which is the group Gate would probe
# for (Level3DIO.check holds the two together), stage 1's gate_0 group 6.
static func _destructibles_here() -> Array:
	var catalog := Level3DIO.read_catalog()
	var doc := Level3DIO.read_path(Level3DMap.level_path())
	var groups := {}
	for e in doc["entities"]:
		groups[e["id"]] = int(e.get("group", -1))
	if Level3DMap.is_stage_one():
		var gate_group := -1
		for o in doc["objects"]:
			if o["asset"] == "Gate":
				gate_group = groups.get(o.get("entity", ""), -1)
		return DESTRUCTIBLE_NAMES.map(func(n): return {"name": n, "kind": n, "move": Transform3D.IDENTITY,
				"group": gate_group if n == "Gate" else -1})
	var out: Array = []
	for o in doc["objects"]:
		var asset: Dictionary = catalog["assets"].get(o["asset"], {})
		if not asset.has("destructible"):
			continue
		var pivot := Vector3(float(asset["pivot"][0]), 0.0, float(asset["pivot"][1]))
		var at := Vector3(float(o["pos"][0]), float(o["pos"][1]), float(o["pos"][2]))
		var move := Transform3D(Basis(Vector3.UP, deg_to_rad(float(o["yaw"]))), at) \
				* Transform3D(Basis.IDENTITY, -pivot)
		out.append({"name": o["id"], "kind": asset["destructible"], "move": move,
				"group": groups.get(o.get("entity", ""), -1)})
	return out


func _add_destructibles() -> void:
	for here in _destructibles_here():
		var building: String = here.name
		var path := DESTRUCTIBLE_PATH % here.kind
		var scene: PackedScene = load(path)
		if scene == null:
			push_error("Cannot load %s -- run export_all() in the stage's Blender file" % path)
			continue
		var root := scene.instantiate()
		root.name = "Dest_" + building
		(root as Node3D).transform = here.move
		add_child(root)
		var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		# The animation is the scene's, shared by every gate made of it.
		var animation := player.get_animation(DESTRUCTION_ANIMATION)
		if not animation.has_meta("sharpened"):
			_sharpen_visibility(animation)
			animation.set_meta("sharpened", true)
		var flash := _find_by_prefix(root, FLASH_NAMES)
		_hide_baked_fire(root)
		_cast_both_sides_of_planes(root)
		_add_collision(root)
		_add_targets(root, true)
		var bodies := []
		for body in root.find_children("*", "StaticBody3D", true, false):
			bodies.append([body.get_parent(), body, body.collision_layer])
		destructibles[building] = {
			"root": root, "player": player, "destroyed": false, "bodies": bodies,
			"kind": here.kind, "group": here.group,
			"centre": flash.global_position if flash else _mesh_aabb(root).get_center(),
		}
		_set_destroyed(building, false)
		destructibles[building].footprint = _footprint(root)
		destructibles[building].roof = _roof(root)


const FLASH_NAMES: Array[String] = ["Blast_Flash", "Gate_Flash", "FX_Blast_Flash"]
# The flash and the smoke baked into every destruction and FX_Blast, which are
# hidden: the preview's own fire and smoke go off in their place
# (Level3DLauncher.blast). The flash was a flat white glow -- J_BlastFlash's
# emission, which glTF does not carry and _light_flashes used to animate --
# and the smoke grey lumps, both beside fire and smoke drawn in bands and
# lines. The shards and the ruins stay.
const BAKED_FIRE_NAMES: Array[String] = ["Blast_Flash", "Gate_Flash", "FX_Blast_Flash",
		"Blast_Smoke", "Gate_Smoke", "FX_Blast_Smoke"]
# How big a destruction's blast is: a unit's, by the scale it asks for
# (BLAST_SCALE), in metres of radius at its peak; a building's, by its
# footprint, a share of its narrow side, and within these.
const UNIT_BLAST_RADIUS := 0.8
const BUILDING_BLAST := 0.5
const BUILDING_BLAST_RADIUS := Vector2(0.9, 1.6)
# A blast that a round sets off goes off this long after the round's own,
# a chain rather than one.
const CHAIN_DELAY := 0.1
const BLENDER_FPS := 24.0
# F0 in jackal_destruction_lib.py: the frame the intact building goes and the
# blast begins, as time into the animation.
const BLAST_FRAME := 10
const BLAST_START := (BLAST_FRAME - 1) / BLENDER_FPS


static func _hide_baked_fire(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if BAKED_FIRE_NAMES.any(func(prefix): return node.name.begins_with(prefix)):
			(node as Node3D).visible = false


# Scale at or below this is the export's "hidden".
const HIDDEN_SCALE := 1e-3


# Blender switches visibility from one frame to the next, and the export samples
# frames, so between a hidden key and a shown one the scale would ramp -- a
# piece growing out of its origin, which for most of them is the middle of the
# map, over a 24th of a second. A key just before the later one, holding the
# earlier value, makes the switch a switch.
static func _sharpen_visibility(animation: Animation) -> void:
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_SCALE_3D:
			continue
		for i in range(animation.track_get_key_count(track) - 1, 0, -1):
			var before: Vector3 = animation.track_get_key_value(track, i - 1)
			var after: Vector3 = animation.track_get_key_value(track, i)
			if (before.x <= HIDDEN_SCALE) != (after.x <= HIDDEN_SCALE):
				animation.track_insert_key(track, animation.track_get_key_time(track, i) - 0.001, before)


# A hidden piece is shrunk to its origin, and so would its collision be: a wall
# too small to see but not to hit. Bodies are off while their mesh is hidden.
func _sync_bodies(entry: Dictionary) -> void:
	for item in entry.bodies:
		var mesh: Node3D = item[0]
		item[1].collision_layer = item[2] if mesh.scale.x > HIDDEN_SCALE else 0


static func _find_by_prefix(root: Node, prefixes: Array) -> Node3D:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		for prefix in prefixes:
			if node.name.begins_with(prefix):
				return node
	return null


# Plays the destruction, or puts the building back as it was.
func _set_destroyed(building: String, destroyed: bool) -> void:
	var entry: Dictionary = destructibles[building]
	var player: AnimationPlayer = entry.player
	entry.destroyed = destroyed
	player.play(DESTRUCTION_ANIMATION)
	# Played from the blast, not from frame 1: the frames before it are the
	# intact building standing, and a rocket that hits it should not be seen to
	# go off a third of a second before the building does.
	player.seek(BLAST_START if destroyed else 0.0, true)
	if not destroyed:
		player.pause()
	else:
		if launcher != null and entry.has("footprint"):
			Level3DAudio.play("building", entry.centre)
			var footprint: Rect2 = entry.footprint
			launcher.blast(entry.centre, clampf(minf(footprint.size.x, footprint.size.y) * BUILDING_BLAST,
					BUILDING_BLAST_RADIUS.x, BUILDING_BLAST_RADIUS.y), CHAIN_DELAY)
		if friends != null:
			friends.building_destroyed(building)
	# Gate.attack: the gate's group opens the way on the grid, which is what
	# the BTR drives by.
	if destroyed and entry.kind == "Gate" and map != null and entry.group >= 0:
		map.trigger_group(entry.group)
	_sync_bodies(entry)
	_ruin_craters(building, destroyed)


# Where a building's blast scorched the ground -- its *_D_Soot, the gate's
# Gate_Soot_0 and _1, flat ovals on the ground -- there is a crater instead,
# as a rocket leaves (Level3DLauncher.make_crater): its outer foot
# RUIN_CRATER_REACH past the scorch's edge, oval as the scorch is, as high and
# deep as a round crater as wide as the oval is narrow. It is the scorch's
# child, so that the destruction's animation shows it when it shows the
# scorch, and the scorch itself is drawn no more. Made the first time the
# building goes down; the launcher is told of it every time, so that the
# hull feels it and no round's crater lies over it, and told when the
# building is put back.
const RUIN_SOOT_NAMES: Array[String] = ["_D_Soot", "Gate_Soot"]
const RUIN_CRATER_REACH := 1.1

func _ruin_craters(building: String, destroyed: bool) -> void:
	if launcher == null:
		return
	if not destroyed:
		launcher.remove_ruin_craters(building)
		return
	var entry: Dictionary = destructibles[building]
	for node in entry.root.find_children("*", "MeshInstance3D", true, false):
		var soot := node as MeshInstance3D
		if not RUIN_SOOT_NAMES.any(func(part): return part in soot.name):
			continue
		var box := soot.get_aabb()
		var radii := Vector2(box.size.x, box.size.z) * 0.5 * RUIN_CRATER_REACH
		var height := minf(radii.x, radii.y)
		var crater: Node3D = soot.get_meta("crater") if soot.has_meta("crater") else null
		if crater == null:
			crater = launcher.make_crater(soot)
			crater.position = Vector3(box.get_center().x, 0.0, box.get_center().z)
			crater.scale = Vector3(radii.x, height, radii.y)
			# On no layer the camera or the sun sees; its children are.
			soot.layers = 0
			soot.set_meta("crater", crater)
		# Where it will be once shown: the scorch is still shrunk to nothing.
		var world := (soot.get_parent() as Node3D).global_transform \
				* Transform3D(soot.basis.orthonormalized(), soot.position) \
				* Transform3D(Basis(), crater.position)
		launcher.add_ruin_crater(building, crater, Vector2(world.origin.x, world.origin.z), radii,
				world.basis.get_euler().y, height)


# What a rocket's explosion destroys: any building whose footprint is within
# BLAST_RADIUS of where it went off -- one stopped by the building's own solid
# tiles, and one that lands at the foot of a wall, as Jackal's grenade does.
const BLAST_RADIUS := 1.2


func _on_exploded(at: Vector3) -> bool:
	_shake(SHAKE_PIXELS)
	# The missile's own Explosion, which goes on to hit the guns it grows over.
	guns.explode(at)
	var any := false
	for building in destructibles:
		var entry: Dictionary = destructibles[building]
		if entry.destroyed:
			continue
		var box: Rect2 = entry.footprint
		var near := Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.z, box.position.y, box.end.y))
		if near.distance_to(Vector2(at.x, at.z)) <= BLAST_RADIUS:
			_set_destroyed(building, true)
			any = true
	return any


# A TravelingExplosion's box this tick (Level3DGuns): the barracks and hangars
# it overlaps go down, as Hut.attack and House.attack let it. The gate does
# not: Gate.attack answers the player's weapon only.
func _on_travel_hit(box: Rect2) -> void:
	for building in destructibles:
		var entry: Dictionary = destructibles[building]
		if not entry.destroyed and entry.kind != "Gate" and box.intersects(entry.footprint):
			_set_destroyed(building, true)


# The intact building from above, for the blast radius: what shows on frame 0.
func _footprint(root: Node) -> Rect2:
	var box := Rect2()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.scale.x <= HIDDEN_SCALE:
			continue
		var world := mesh_instance.global_transform * mesh_instance.get_aabb()
		var flat := Rect2(world.position.x, world.position.z, world.size.x, world.size.z)
		box = flat if first else box.merge(flat)
		first = false
	return box


# The top of what is standing under `root`, as _footprint has it: where a
# building's HELP comes from (Level3DFriends.bind).
func _roof(root: Node) -> float:
	var top := 0.0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.scale.x > HIDDEN_SCALE:
			top = maxf(top, (mesh_instance.global_transform * mesh_instance.get_aabb()).end.y)
	return top


# ----------------------------------------------------------------------------
# The bunkers' guns, and the BTR's dying to them: level3d_guns.gd has the rules.
#
# One jackal_dest_BunkerGun.glb (jackal_bunker_dest.py in jackal_assets.blend)
# on every bunker of the stage, which the stage file has without its gun. The
# yellow gun is the one YELLOW_GUN of stage-0.json; the rest are GRAY_GUN.
const GUN_BUNKERS: Array[String] = ["Bunker_0", "Bunker_1", "Bunker_2", "Bunker_3", "Bunker_4",
		"BunkerN_0", "BunkerN_1", "BunkerN3_0", "BunkerN3_1", "BunkerN3_2", "BunkerN3_3",
		"BunkerN3_4", "BunkerN3_5", "BunkerN3_6", "BunkerN3_7"]
const YELLOW_GUN_BUNKER := "BunkerN3_5"


# The bunkers that get a gun, each [its node's name, whether the gun is the
# gray one rather than the yellow]. Stage 1's are GUN_BUNKERS, by the names
# the hand-built level gave them; another level's are its gun entities',
# each on the Bunker object that belongs to it in the level file, which the
# builder names by its id (the level editor puts the two down together).
static func _gun_bunkers() -> Array:
	if Level3DMap.is_stage_one():
		return GUN_BUNKERS.map(func(n): return [n, n != YELLOW_GUN_BUNKER])
	var doc := Level3DIO.read_path(Level3DMap.level_path())
	var out: Array = []
	for e in doc["entities"]:
		if e["type"] != "GRAY_GUN" and e["type"] != "YELLOW_GUN":
			continue
		for o in doc["objects"]:
			if o.get("entity", "") == e["id"] and o["asset"] == "Bunker":
				out.append([o["id"], e["type"] == "GRAY_GUN"])
	return out
const BLAST_PATH := "res://resources/3d/jackal_fx_blast.glb"

var _immortal := false  # --immortal: rounds pass the BTR by, for --shot runs
var _hud: CanvasLayer
# The spare lives, as Main.extra_lives: the game's four on normal (Crew.lives).
# The last one lost starts the stage again, as R does -- with two players, the
# last one lost of both -- and the game's continue screen is not here. The
# infinite lives cheat spends none.
const EXTRA_LIVES := 4
var _blast_scene: PackedScene
# --hold: [key, from tick, to tick, player], and the ticks since the preview
# went live.
var _held: Array = []
var _ticks := 0


# Over the player's jeep, as it goes: "1UP", "POWER UP" (Level3DScorePops).
# CREW_POP_HEIGHT is over the turret.
const CREW_POP_HEIGHT := 2.2

func _crew_pop(c: Crew, text: String) -> void:
	if settings.hud:
		_score_pops.add_text(func() -> Vector3: return c.btr.position + Vector3(0.0, CREW_POP_HEIGHT, 0.0),
				text, _crew_colour(c.index))


# PlayerState.add_points: the points, and a life at 20000 and every 50000
# after it, which the preview went without until the HUD showed lives coming.
func _add_points(c: Crew, points: int) -> void:
	var before := c.score
	c.score += points
	if (before < 20000 and c.score >= 20000) 			or ((before - 20000) / 50000 != (c.score - 20000) / 50000):
		c.lives += 1
		Level3DAudio.play("extra_life")
		_crew_pop(c, "1UP")
		if guns.verbose:
			print("%dP extra life at %d, %d lives" % [c.index + 1, c.score, c.lives])
	_show_state()


func _add_guns(level: Node) -> void:
	# The game's own map under the level: what walks, walks on it, and what
	# stops an enemy's round is its solid tiles (Level3DMap).
	map = Level3DMap.new()
	guns = Level3DGuns.new()
	guns.frame = _view_frame
	guns.solid = func(x: float, z: float):
		var p := Level3DMap.to_map(Vector2(x, z))
		return map.is_solid(p.x, p.y)
	guns.player_attack = _attack_player
	guns.hull = func(at: Vector3) -> Dictionary:
		return helicopter.strike(at) if helicopter != null else {}
	guns.player_position = func(from: Vector2) -> Vector2:
		var c := _target(from)
		return Vector2(c.btr.position.x, c.btr.position.z)
	guns.blast = _spawn_blast
	guns.scored = func(points: int):
		_add_points(_credited(), points)
	add_child(guns)
	soldiers = Level3DSoldiers.new()
	soldiers.map = map
	soldiers.guns = guns
	soldiers.frame = _view_frame
	soldiers.ground = _walker_ground_at
	soldiers.player_position = guns.player_position
	soldiers.scored = guns.scored
	# Under whichever player's vehicle he is, and the kill that player's.
	soldiers.run_over = func(p: Vector3, margin: float, sideways: bool) -> Vector3:
		if chinook != null:
			return Vector3.ZERO
		for c in crews:
			if c.out or c.respawning > 0:
				continue
			var out := c.btr.push_out(p, margin, sideways)
			if out != Vector3.ZERO:
				guns.acting = c
				return out
		return Vector3.ZERO
	add_child(soldiers)
	boats = Level3DBoats.new()
	boats.map = map
	boats.guns = guns
	boats.frame = _view_frame
	boats.ground = _ground_at
	boats.player_position = guns.player_position
	boats.scored = guns.scored
	add_child(boats)
	tanks = Level3DTanks.new()
	tanks.map = map
	tanks.guns = guns
	tanks.frame = _view_frame
	tanks.ground = _ground_at
	tanks.player_position = guns.player_position
	tanks.scored = guns.scored
	add_child(tanks)
	boss = Level3DBoss.new()
	boss.map = map
	boss.guns = guns
	boss.frame = _view_frame
	boss.ground = _ground_at
	boss.player_position = guns.player_position
	boss.scored = guns.scored
	add_child(boss)
	# What their wheels and tracks leave behind, and the player's.
	tracks = Level3DTracks.new()
	tracks.ground = _ground_at
	tracks.sources = [btr.wheel_tracks, tanks.track_contacts, boss.track_contacts]
	add_child(tracks)
	# And the dust they raise, and everything's exhaust.
	puffs = Level3DPuffs.new()
	puffs.ground = _ground_at
	puffs.sources = [btr.puffs, tanks.puffs, boss.puffs, boats.puffs]
	add_child(puffs)
	# The boss tanks are not in explosion_hit: nothing but the player's own
	# weapons hurts them (BossBlueTank.attack).
	guns.explosion_hit = func(box: Rect2, player: bool):
		soldiers.explosion_hit(box, player)
		boats.explosion_hit(box, player)
		tanks.explosion_hit(box, player)
	friends = Level3DFriends.new()
	friends.map = map
	friends.guns = guns
	friends.soldiers = soldiers
	friends.frame = _view_frame
	friends.ground = _walker_ground_at
	friends.player_position = guns.player_position
	friends.calls = settings.hud and settings.hud_help
	# The prisoners' HELP and the rescue crewman's HERE! (Level3DRescueCrew).
	_callouts.marks = func() -> Array[Dictionary]:
		var marks := friends.help_marks()
		if rescue != null:
			marks.append_array(rescue.crew.call_marks())
		return marks
	friends.scored = guns.scored
	add_child(friends)
	rescue = Level3DRescue.new()
	rescue.map = map
	rescue.friends = friends
	rescue.frame = _view_frame
	rescue.ground = _ground_at
	rescue.players = func() -> Array:
		var out := []
		for c in crews:
			if not c.out:
				out.append([Vector2(c.btr.position.x, c.btr.position.z), c.carrier])
		return out
	rescue.scored = func(points: int, carrier: Level3DFriends.Carrier):
		for c in crews:
			if c.carrier == carrier:
				_rescued_by.append(c.index)
				# The points first, and then the 1UP they may bring.
				if settings.hud:
					_score_pops.add(rescue.top_position(), points, _crew_colour(c.index))
				_add_points(c, points)
		_show_state()
	add_child(rescue)
	rescue.crew.calls = friends.calls
	if Level3DMap.is_stage_one():
		rescue.bind_lamps(level)  # the landing port's, which is stage 1's
	soldiers.more_solids = friends.solid_boxes
	var centres := {}
	var kinds := {}
	var roofs := {}
	for building in destructibles:
		centres[building] = destructibles[building].footprint.get_center()
		kinds[building] = destructibles[building].kind
		roofs[building] = destructibles[building].roof
	friends.bind(centres, kinds, roofs)
	# The cells each POW building's and gate's group opens, for _dull_at.
	_dull_cells.clear()
	for building in destructibles:
		var kind: String = destructibles[building].kind
		var group: int = destructibles[building].group if kind == "Gate" else friends.group_of(building)
		if group >= 0 and group < map.stage.groups.size():
			for cell in map.stage.groups[group]:
				_dull_cells[Vector2i(cell[0], cell[1])] = building
	friends.carriers.append(crews[0].carrier)
	# The players' weapons are wired to all of these in _arm.
	guns.travel_hit = _on_travel_hit
	_blast_scene = load(BLAST_PATH)
	var scene: PackedScene = load(Level3DGuns.GUN_PATH)
	if scene == null or _blast_scene == null:
		push_error("Cannot load the gun or the blast -- run export() in jackal_assets.blend and jackal_fx.blend")
		return
	for pair in _gun_bunkers():
		var bunker_name: String = pair[0]
		var bunker := level.find_child(bunker_name, true, false) as Node3D
		if bunker == null:
			push_warning("No %s in %s; it gets no gun" % [bunker_name, level_path])
			continue
		var root := scene.instantiate() as Node3D
		root.name = "Gun_" + bunker_name
		add_child(root)
		root.global_transform = bunker.global_transform
		# Lit by the gun's flash, and the bunker round it (Level3DGuns.muzzle_flash).
		Level3DFx.flash_lit(root, Level3DFx.ENEMY_FLASH_LAYER)
		Level3DFx.flash_lit(bunker, Level3DFx.ENEMY_FLASH_LAYER)
		var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_sharpen_visibility(player.get_animation(DESTRUCTION_ANIMATION))
		_cast_both_sides_of_planes(root)
		var base_bodies := []
		for body in bunker.find_children("*", "StaticBody3D", true, false):
			base_bodies.append([body, body.collision_layer])
		# Switched with the ruin's bodies: on once the gun is gone.
		base_bodies.append([_add_bunker_ramp(bunker), RAMP_LAYER])
		guns.add(bunker_name, root, player, pair[1], base_bodies)


# A bunker whose gun is gone is floor in the game -- its cells were empty all
# along; the gun's own boxes were what kept the jeep off -- so the BTR drives
# over it, and here it has to climb the concrete to do so, or it runs through
# it at sand level. What it climbs is not the concrete, whose edge is a step
# and whose wreck is jagged, but a frustum over it on RAMP_LAYER: its top the
# bunker's top plate at the height of the wreck's ring, its foot on the ground
# just far enough out that its slope passes over the slab's edge. Built in the
# bunker's own axes from its meshes, so it fits a bunker however it is turned.
const RAMP_TOP := 0.72      # over the wreck's ring, which stands to 0.69

func _add_bunker_ramp(bunker: Node3D) -> StaticBody3D:
	var into_bunker := bunker.global_transform.affine_inverse()
	var slab := AABB()
	var top := AABB()
	var first := true
	for node in bunker.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var box: AABB = into_bunker * mesh_instance.global_transform * mesh_instance.get_aabb()
		slab = box if first else slab.merge(box)
		first = false
		if String(mesh_instance.name).begins_with("Bunker_Top"):
			top = box
	var foot := slab.position.y
	var centre := slab.get_center()
	var slab_half := Vector2(slab.size.x, slab.size.z) * 0.5
	var top_half := Vector2(top.size.x, top.size.z) * 0.5 if top.has_volume() else slab_half * 0.64
	# The slab's own height, without the plate, rivets and slit on it.
	var slab_height := top.position.y - foot if top.has_volume() else slab.size.y * 0.7
	var rise := RAMP_TOP
	# The run out past the slab's edge at which the slope is slab_height high
	# over that edge, on the slab's longer half.
	var inset := maxf(slab_half.x - top_half.x, slab_half.y - top_half.y)
	var run := slab_height * inset / maxf(rise - slab_height, 0.01) + 0.05
	var points := PackedVector3Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c := corner as Vector2
		points.append(Vector3(centre.x + c.x * (slab_half.x + run), foot, centre.z + c.y * (slab_half.y + run)))
		points.append(Vector3(centre.x + c.x * top_half.x, foot + rise, centre.z + c.y * top_half.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var holder := CollisionShape3D.new()
	holder.shape = shape
	var body := StaticBody3D.new()
	body.name = "Ramp"
	body.collision_layer = 0
	body.collision_mask = 0
	body.add_child(holder)
	bunker.add_child(body)
	_kinds[body.get_rid()] = "ruin"
	return body


# Of the enemies' intercepts, the one a weapon meets first: {} for none.
static func _nearest(found: Array) -> Dictionary:
	var best := {}
	for f: Dictionary in found:
		if not f.is_empty() and (best.is_empty() or f.t < best.t):
			best = f
	return best


# A unit's or the BTR's blast: FX_Blast from jackal_fx.blend for its shards,
# played once from its blast frame and gone, and the launcher's fire and smoke
# (Level3DLauncher.blast) for its flash and smoke. A unit is brought down by a
# round, whose own blast goes first; the BTR by a round or a collision, which
# has none, so its goes off at once.
func _spawn_blast(at: Vector3, size: float, delay := CHAIN_DELAY, sound := "blast") -> void:
	Level3DAudio.play(sound, at)
	var root := _blast_scene.instantiate() as Node3D
	add_child(root)
	root.global_position = at
	root.scale = Vector3.ONE * size
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_sharpen_visibility(player.get_animation(DESTRUCTION_ANIMATION))
	_hide_baked_fire(root)
	launcher.blast(at, size * UNIT_BLAST_RADIUS, delay)
	player.play(DESTRUCTION_ANIMATION)
	player.seek(BLAST_START, true)
	get_tree().create_timer(DESTRUCTION_SETTLE).timeout.connect(root.queue_free)


# The top view's frame in x, z -- the game's screen, for what is on it.
func _view_frame() -> Rect2:
	var width := level_aabb.size.x / zoom
	var half_height := width * 9.0 / 32.0
	return Rect2(focus.x - width * 0.5, focus.y - half_height, width, half_height * 2.0)


# GameMode.attack_players: Player.attack, 32 px either side, on each player in
# the game until one is hit.
func _attack_player(x: float, z: float) -> bool:
	if _immortal or settings.bullet_hack or chinook != null:
		return false
	var half := 32.0 * Level3DGuns.PX
	for c in crews:
		if c.out or c.respawning > 0 or c.invincible > 0:
			continue
		if absf(x - c.btr.position.x) > half or absf(z - c.btr.position.z) > half:
			continue
		_explode_btr(c, "shot")
		return true
	return false


# Player.update's box for its mines: 32 px either side, 48 along x when facing
# east or west and 46 along y when facing north or south. The BTR's heading is
# not held to eight directions, so the nearest of them decides.
func _player_box(c: Crew) -> Rect2:
	var octant := wrapi(int(roundf(c.btr.heading / (PI / 4.0))), 0, 8)
	var half := Vector2(32.0, 32.0)
	if octant == 0 or octant == 4:
		half.x = 48.0
	elif octant == 2 or octant == 6:
		half.y = 46.0
	half *= Level3DGuns.PX
	return Rect2(Vector2(c.btr.position.x, c.btr.position.z) - half, half * 2.0)


# Player.explode: the blast, the BTR gone, and back after RESPAWN_DELAY where
# it went, invincible, for one of its lives (_physics_process). Under the blast a copy of it comes apart and burns until it is back
# (Level3DWreck); the game's jeep is simply gone.
func _explode_btr(c: Crew, by: String) -> void:
	var vehicle := c.btr
	_spawn_blast(vehicle.position + Vector3.UP * 0.6, 1.0, 0.0, "player_explodes")
	# Player.explode: the last life going takes the music with it -- the last
	# of both players'.
	if c.lives == 0 and not settings.infinite_lives and not _other_in(c):
		Level3DAudio.stop_music()
	var wreck := Level3DWreck.new()
	wreck.ground = launcher.ground
	wreck.launcher = launcher
	add_child(wreck)
	wreck.build(vehicle)
	# Its own Explosion, which spares the guns and not the soldiers.
	guns.acting = c
	guns.explode(vehicle.position, true)
	friends.player_died(vehicle.position, c.carrier)
	_shake(SHAKE_PIXELS)
	vehicle.stop()
	vehicle.visible = false
	c.respawning = Player.RESPAWN_DELAY
	if guns.verbose:
		print("%dP destroyed (%s) at %.1f, %.1f" % [c.index + 1, by, vehicle.position.x, vehicle.position.z])


func _make_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = HUD_LAYER
	var layer := _hud
	add_child(layer)
	# The players' lines are added with them (_add_crew).
	_pad_arrow = Level3DArrow.new()
	layer.add_child(_pad_arrow)
	_callouts = Level3DCallouts.new()
	layer.add_child(_callouts)
	_score_pops = Level3DScorePops.new()
	layer.add_child(_score_pops)
	_summary = Level3DSummary.new()
	layer.add_child(_summary)
	_hints = Level3DHints.new()
	layer.add_child(_hints)
	_banners = Level3DBanners.new()
	layer.add_child(_banners)
	var crosshair := Level3DCrosshair.new()
	crosshair.wanted = _crosshair_wanted
	crosshair.hide_pointer = func(): return _title != null and _title.pointer_hidden() \
			or _menu != null and _menu.pointer_hidden()
	layer.add_child(crosshair)


# The lines' corner and size, from Level3DSettings (Level3DHud draws them),
# and their icons rendered again for a new size.
func _layout_hud() -> void:
	_callouts.scale_factor = settings.hud_scale
	Level3DFont.style = settings.font
	_hints.scale_factor = settings.hud_scale
	_banners.scale_factor = settings.hud_scale
	_summary.scale_factor = settings.hud_scale
	_score_pops.scale_factor = settings.hud_scale
	for c in crews:
		c.hud.bottom = settings.hud_corner == Level3DSettings.HudCorner.BOTTOM
		c.hud.two_rows = settings.hud_two_rows
		c.hud.scale_factor = settings.hud_scale
		c.hud.icons = crews[0].hud.icons
		c.hud.queue_redraw()
	if not crews.is_empty() and sun != null and crews[0].hud.icon_pixels() != _icon_pixels:
		_render_icons()


# The HUD's icons off the preview's own models (Level3DIcons), lit by its sun.
# A few frames' work, so a size changed again before it is done starts over,
# and only the last one's are kept.
var _icons: Level3DIcons
var _icon_pixels := -1
var _icon_run := 0

func _render_icons() -> void:
	if _icons == null:
		_icons = Level3DIcons.new()
		add_child(_icons)
	_icons.sun_energy = _day_sun_energy()
	_icons.shade = SHADE
	_icon_pixels = crews[0].hud.icon_pixels()
	_icon_run += 1
	var run := _icon_run
	var rendered: Dictionary = await _icons.render_all(btr.vehicle, _icon_pixels, BLUE_HUES)
	if run == _icon_run:
		for c in crews:
			c.hud.icons = rendered
			c.hud.queue_redraw()
		_summary.icons = rendered


const FIRING_NAMES := ["CLASSIC", "CURSOR", "COMBINED"]
# How long V and M show the modes when the HUD does not (hud_modes off).
const MODES_FLASH_TIME := 2.0
var _modes_flash := 0   # the flashes still running; the modes show while > 0

# Every player's line from the run's state. A player out of the game keeps
# his score on it and nothing else.
func _show_state() -> void:
	var on := settings.hud
	for c in crews:
		var line := c.hud
		line.parts = {"score": on and settings.hud_score, "lives": on and settings.hud_lives and not c.out,
				"pows": on and settings.hud_pows and friends != null and not c.out,
				"weapon": on and settings.hud_weapon and friends != null and not c.out}
		line.score = c.score
		line.lives = -1 if settings.infinite_lives else c.lives
		line.pows = c.carrier.pows
		line.has_missiles = c.carrier.has_missiles
		line.missile_power = c.carrier.missile_power
		var weapon := 1 + c.carrier.missile_power if c.carrier.has_missiles else 0
		if weapon > c.weapon_shown and c.weapon_shown >= 0:
			_crew_pop(c, "POWER UP")
		c.weapon_shown = weapon
		line.modes = ""
		line.cheats = ""
		if c.index == 0:
			# The flash shows with the HUD off as well: a key that changes the
			# driving has to say what it changed it to.
			if on and settings.hud_modes or _modes_flash > 0:
				line.modes = "%s DRIVE  %s FIRE" % ["CLASSIC" if btr.classic else "FREE",
						FIRING_NAMES[settings.firing]]
			line.cheats = _cheats_text() if on and settings.hud_cheats else ""
		line.show_state()


# The cheats that are on, in words the font has and short enough for the
# line at 150% (Level3DSettings: the Cheats tab), or "" for none.
func _cheats_text() -> String:
	var on: Array[String] = []
	if settings.infinite_lives:
		on.append("LIVES")
	if settings.wall_hack:
		on.append("WALLS")
	if settings.bullet_hack:
		on.append("BULLETS")
	if settings.gun_rate != 1.0:
		on.append("GUN X" + _rate_text(settings.gun_rate))
	if settings.launcher_rate != 1.0:
		on.append("ROCKET X" + _rate_text(settings.launcher_rate))
	return "" if on.is_empty() else "CHEATS: " + "  ".join(on)


# 2, not 2.0; 0.5 as it is.
static func _rate_text(rate: float) -> String:
	return str(int(rate)) if rate == floorf(rate) else str(rate)


# The arrow to the rescue helicopter's pad: while there are prisoners aboard
# and it is there, or on its way, to take them. Every frame, after the camera
# has moved; the arrow itself hides while the pad is in the frame.
var _pad_arrow: Level3DArrow
# The prisoners' HELP, the game's and the calls (Level3DFriends.help_marks).
var _callouts: Level3DCallouts
# The points over the rescue helicopter for each prisoner it takes.
var _score_pops: Level3DScorePops

func _update_pad_arrow() -> void:
	_pad_arrow.shown = settings.hud and settings.hud_pad_arrow \
			and friends.pows_aboard() > 0 and rescue.is_waiting()
	if _pad_arrow.shown:
		_pad_arrow.camera = camera
		_pad_arrow.target = rescue.pad_position()
		_pad_arrow.bottom_inset = _hud_bottom_inset()
	_pad_arrow.queue_redraw()
	_callouts.camera = camera
	_score_pops.camera = camera
	_hints.camera = camera


# The three moments (Level3DBanners), each on the edge of what it marks: the
# Chinook coming and going, the boss's pan starting and ending, the fourth
# boss tank going. R forgets all three (_restart), so a new run shows them
# again.
var _banners: Level3DBanners
var _saw_chinook := false
var _saw_pan := false
var _saw_defeat := false
# The controls taught over each jeep (Level3DHints), in this order, each as
# it is first wanted and until it is done: once a run of the preview, R or
# not -- "<player>:<hint>" in `_hints_done`. `_hints_up` is each player's up,
# {"name", "hint", "from" -- where the jeep was when it came up}.
const HINTS := ["move", "fire", "rocket"]
# The fire hint comes with an enemy within HINT_REACH of the gun's reach; the
# rocket's with a POW building or a gate within the launcher's, and the BTR
# turned to it to within HINT_FACING -- or a round thudding on one.
const HINT_REACH := 1.25
const HINT_FACING := deg_to_rad(35.0)
var _hints: Level3DHints
var _hints_done := {}
var _hints_up := {}
var _hints_off := false     # past the boss: nothing left to teach
var _thud := false          # a round has thudded on a POW building or a gate (_dull_at)

func _update_hints() -> void:
	var on := settings.hud and settings.hud_hints and chinook == null and not _hints_off and not _summary.shown
	for c in crews:
		var up: Dictionary = _hints_up.get(c.index, {})
		if not on or c.out or c.respawning > 0:
			if not up.is_empty():
				_hints.done(up.hint)
				_hints_up.erase(c.index)
			continue
		if not up.is_empty():
			if _hint_done(c, up):
				_hints_done["%d:%s" % [c.index, up.name]] = true
				_hints.done(up.hint)
				_hints_up.erase(c.index)
			continue
		for name in HINTS:
			if _hints_done.has("%d:%s" % [c.index, name]) or not _hint_wanted(c, name):
				continue
			var words := {"move": "MOVE", "fire": "FIRE", "rocket": "ROCKET"}
			var btr_of := c.btr
			_hints_up[c.index] = {"name": name, "from": c.btr.position, "rockets": c.rockets,
					"hint": _hints.show_hint(_hint_keys(c, name), words[name],
							func() -> Vector3: return btr_of.position + Vector3(0.0, Level3DHints.HEIGHT, 0.0))}
			break


# Whether the hint `name` is wanted now: moving at once; firing when an enemy
# soldier or tank is within HINT_REACH of the gun's reach; the rocket when a
# POW building or a gate still standing is within the launcher's and the BTR
# faces it, or a round has thudded on one.
func _hint_wanted(c: Crew, name: String) -> bool:
	var at := Vector2(c.btr.position.x, c.btr.position.z)
	match name:
		"move":
			return true
		"fire":
			if not _hints_done.has("%d:move" % c.index):
				return false
			var reach := _gun_reach() * HINT_REACH
			for p in soldiers.soldiers.map(func(s): return Vector2(s.x, s.y)) \
					+ tanks.tanks.map(func(t): return Vector2(t.x, t.y)):
				if Level3DMap.to_level(p).distance_to(at) < reach:
					return true
			return false
		"rocket":
			if _thud:
				return true
			var forward := Vector2(c.btr.forward().x, c.btr.forward().z)
			for building in destructibles:
				var entry: Dictionary = destructibles[building]
				var kind: String = entry.kind
				if entry.destroyed or not entry.has("footprint") or kind != "Gate" \
						and not Level3DFriends.HUT_KINDS.has(kind) and not Level3DFriends.HOUSE_KINDS.has(kind):
					continue
				var to: Vector2 = (entry.footprint as Rect2).get_center() - at
				if to.length() < _launcher_reach(c) and absf(forward.angle_to(to)) < HINT_FACING:
					return true
			return false
	return false


# The gun's and the launcher's reach as the settings have them
# (Level3DSettings.Reach), level metres.
func _gun_reach() -> float:
	match settings.reach:
		Level3DSettings.Reach.UNLIMITED:
			return Level3DGun.UNLIMITED_RANGE
		Level3DSettings.Reach.LONG:
			return Level3DGun.RANGE
	return Level3DGun.CLASSIC_RANGE


func _launcher_reach(c: Crew) -> float:
	match settings.reach:
		Level3DSettings.Reach.UNLIMITED:
			return Level3DGun.UNLIMITED_RANGE
		Level3DSettings.Reach.LONG:
			return Level3DLauncher.RANGE
	return Level3DLauncher.MISSILE_RANGE if c.carrier.has_missiles else Level3DLauncher.GRENADE_RANGE


# Whether the hint up has been done: driven a couple of metres, the gun fired,
# a rocket or a grenade fired.
func _hint_done(c: Crew, up: Dictionary) -> bool:
	match up.name:
		"move":
			return c.btr.position.distance_to(up.from) > 2.0
		"fire":
			return c.gun.trigger
		"rocket":
			return c.rockets > up.rockets
	return true


# The keys a hint shows, as the player has them now: the first player's from
# the settings, the mouse's buttons when the firing mode aims with it; the
# second's from Main's second mapping.
func _hint_keys(c: Crew, name: String) -> Array:
	if c.input == null:
		var mouse := settings.firing != Level3DSettings.Firing.CLASSIC
		match name:
			"move":
				return [settings.key("up"), settings.key("left"), settings.key("down"), settings.key("right")] \
						.map(func(k): return _key_name(k))
			"fire":
				return ["LMB"] if mouse else [_key_name(settings.key("gun"))]
			"rocket":
				return ["RMB"] if mouse else [_key_name(settings.key("rocket"))]
	var m := _mapping_2
	match name:
		"move":
			if [m.key_up, m.key_left, m.key_down, m.key_right] == [KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
				return ["ARROWS"]
			return [m.key_up, m.key_left, m.key_down, m.key_right].map(func(k): return _key_name(k))
		"fire":
			return [_key_name(m.key_gun, m.key_gun_location)]
		"rocket":
			return [_key_name(m.key_grenade, m.key_grenade_location)]
	return []


# A key as the font can write it: its name in capitals, R- for the right one
# of a pair.
static func _key_name(key: Key, location := KEY_LOCATION_UNSPECIFIED) -> String:
	var name := OS.get_keycode_string(key).to_upper()
	return ("R-" + name) if location == KEY_LOCATION_RIGHT else name


# The mission's summary (Level3DSummary) in place of the game's lines: who
# brought each prisoner rescued in, in order, and the tick the BTR was handed
# over on, which its time is from.
var _summary: Level3DSummary
var _rescued_by: Array[int] = []
var _mission_from := 0
var _summary_tick := -1         # --summary's: the tick to show it on, as if the boss were beaten

func _update_banners() -> void:
	var on := settings.hud
	var flying := chinook != null
	if flying and not _saw_chinook and on and settings.banner_stage:
		_banners.stage(1)
	elif not flying and _saw_chinook:
		_banners.stage_over()
		_mission_from = _ticks
	_saw_chinook = flying
	var panning := boss != null and boss.is_panning()
	if panning and not _saw_pan and on and settings.banner_warning:
		_banners.warning()
	elif not panning and _saw_pan:
		_banners.warning_over()
	_saw_pan = panning
	var defeated := boss != null and boss.is_defeated()
	_hints_off = _hints_off or defeated
	var forced := _summary_tick >= 0 and _ticks >= _summary_tick and not _summary.shown
	if forced:
		_summary_tick = -1
	if forced or defeated and not _saw_defeat and on and settings.banner_mission:
		_summary.show_summary(_rescued_by, friends.prisoners_total(), _ticks - _mission_from)
	_saw_defeat = defeated


# The reticle: while the mouse aims something and there is a BTR to aim it --
# not over the Escape menu, not while the Chinook flies it in, not while it is
# gone -- as the game's is gated on playing, unpaused and aiming.
func _crosshair_wanted() -> bool:
	return _live and settings.hud_crosshair \
			and settings.firing != Level3DSettings.Firing.CLASSIC \
			and not _menu.is_open() and not _title.is_open() and chinook == null and crews[0].respawning == 0 and not crews[0].out


# V and M: the modes on the HUD line for MODES_FLASH_TIME after the last press
# -- each press starts a timer of its own, and the line drops the modes when
# the last one runs out.
func _flash_modes() -> void:
	_modes_flash += 1
	_show_state()
	get_tree().create_timer(MODES_FLASH_TIME, false).timeout.connect(func():
		_modes_flash -= 1
		_show_state())


# The Escape menu, and under it the look it picks: rects over the whole
# frame, each drawing it again through level3d_screen.gdshader -- the light
# preset's grade, the pixels, then the HUD, then the CRT's glass over all of
# it. The grade is the stage's, so under the HUD. The HUD is over the pixels
# because they would make it unreadable, and under the glass because it is on
# the screen.
const GRADE_LAYER := 49
const PIXELS_LAYER := 50
const HUD_LAYER := 51
const CRT_LAYER := 52

func _make_menu() -> void:
	_grade = _screen_pass(GRADE_LAYER, 3)
	_pixels = _screen_pass(PIXELS_LAYER, 2)
	_crt = _screen_pass(CRT_LAYER, 1)
	_menu = Level3DMenu.new()
	_menu.settings = settings
	_menu.from_editor = OS.get_cmdline_user_args().has("--editor")
	_menu.changed = _settings_changed
	_menu.resumed = func(): _gun_locked = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	# A new game, for one player or two: the run started again with them.
	_menu.new_game = func(count: int):
		_set_players(count)
		_restart()
		_menu.close()
	_menu.main_menu = _show_title
	# Over the HUD, so that its black hides it, and under the CRT's glass.
	_title = Level3DTitle.new()
	_title.layer = HUD_LAYER
	_title.settings = settings
	_title.start = _start_game
	# The settings over it, back to it: open again, in the font they leave.
	_title.open_settings = func(): _menu.open_settings(_title.open)
	_title.settings_open = _menu.is_open
	_title.changed = _settings_changed
	add_child(_title)
	add_child(_menu)


# The title screen over the stage, the tree paused under it and its own song
# playing (Level3DAudio.MUSIC's "title").
func _show_title() -> void:
	_menu.leave()
	get_tree().paused = true
	Level3DAudio.play_music("title")
	_title.open()


# A game picked on the title screen: the run from the top, with the start
# jingle, for `count` players at the difficulty picked there.
func _start_game(count: int) -> void:
	while not _live:
		await get_tree().process_frame
	Level3DMap.hard = settings.hard
	get_tree().paused = false
	_gun_locked = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_set_players(count)
	_restart(true)


# A rect on a layer of its own drawing the frame through the shader's `mode`.
# The back buffer is copied again for each: without it the CRT would read the
# frame as it was before the pixels and the HUD.
func _screen_pass(layer_index: int, mode: int) -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = layer_index
	add_child(layer)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(copy)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SCREEN_SHADER
	material.set_shader_parameter("mode", mode)
	rect.material = material
	rect.visible = false
	layer.add_child(rect)
	return rect


# The 3D at the screen's own pixels. The project draws everything into
# 2048x1152 and scales that to the window (stretch mode "viewport"), which is
# right for the 2D game, whose frame is the map's width, and left the 3D a
# little soft on a bigger screen. Here the window's content is scaled as
# canvas items instead: the 3D is drawn at the window's size, and the HUD and
# the menu, which were laid out on 2048x1152, are scaled up to it as before.
# A resolution of its own (Level3DSettings.resolution) is Viewport's 3D
# scaling, from the width the 3D actually has in the window.
#
# Not for a --shot, whose image stays 2048x1152 whatever window it was taken in.
var _window_watched := false

func _apply_resolution() -> void:
	if not _persist:
		return
	var window := get_window()
	if not _window_watched:
		_window_watched = true
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.size_changed.connect(_apply_resolution)
	var viewport := get_viewport()
	var wanted: Vector2i = Level3DSettings.RESOLUTIONS[settings.resolution]
	var base := Vector2(window.content_scale_size)
	var drawn := base.x * minf(window.size.x / base.x, window.size.y / base.y)
	if wanted == Vector2i.ZERO or drawn <= 0.0:
		viewport.scaling_3d_scale = 1.0
	else:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = clampf(wanted.x / drawn, 0.25, 2.0)


# From the menu, and from the keys that change the same things (Tab, V, M).
func _settings_changed() -> void:
	_apply_settings()
	if _persist:
		settings.save()


func _apply_settings() -> void:
	tilted = settings.camera == Level3DSettings.Camera.TILTED
	for c in crews:
		c.btr.classic = settings.driving == Level3DSettings.Driving.CLASSIC
		c.btr.ghost = settings.wall_hack
		c.gun.unlimited = settings.reach == Level3DSettings.Reach.UNLIMITED
		c.launcher.unlimited = c.gun.unlimited
		c.gun.long_reach = settings.reach == Level3DSettings.Reach.LONG
		c.launcher.long_reach = c.gun.long_reach
		c.gun.rate = settings.gun_rate
		c.launcher.rate = settings.launcher_rate
	_apply_resolution()
	_pixels.visible = settings.look == Level3DSettings.Look.PIXELS
	# --light over the setting, for a --shot, which reads no settings.
	var light_flag := OS.get_cmdline_user_args().find("--light")
	lighting = Level3DLighting.from_name(OS.get_cmdline_user_args()[light_flag + 1]) 			if light_flag >= 0 else settings.light as Level3DLighting.Preset
	_apply_lighting()
	_crt.visible = settings.crt
	if friends != null:
		friends.calls = settings.hud and settings.hud_help
		if rescue != null and rescue.crew != null:
			rescue.crew.calls = friends.calls
	# Under the title, before the stage and its HUD are built (_ready), only
	# the font, which the title is drawn in too.
	if _hud != null:
		_layout_hud()
		_show_state()
	else:
		Level3DFont.style = settings.font
	Level3DAudio.set_mode(settings.sound_mode as Level3DAudio.Mode)
	Level3DAudio.set_adaptive(settings.boss_music == Level3DSettings.BossMusic.ADAPTIVE)
	Level3DAudio.set_volumes(settings.master_volume, settings.music_volume, settings.effects_volume,
			settings.enemy_fire_volume, settings.enemy_fire)
	Level3DAudio.set_gains(settings.sound_gains)
	# At once, under the menu, which has the tree paused and _process with it.
	if camera != null:
		_update_camera()


func _make_markers() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.5
	ring.rings = 24
	ring.ring_segments = 6
	_marker_mesh = ring
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _sync_markers() -> void:
	while _markers.size() < btr.waypoints.size():
		var marker := MeshInstance3D.new()
		marker.mesh = _marker_mesh
		marker.material_override = _marker_material
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker)
		_markers.append(marker)
	for i in _markers.size():
		var shown := i < btr.waypoints.size()
		_markers[i].visible = shown
		if shown:
			var at: Vector3 = btr.waypoints[i]
			var ground: Dictionary = _ground_at(at.x, at.z)
			_markers[i].position = Vector3(at.x, ground.height + 0.05, at.z)


func _mesh_aabb(root: Node, leave_out: Array[String] = []) -> AABB:
	var result := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if leave_out.any(func(prefix: String) -> bool: return mesh_instance.name.begins_with(prefix)):
			continue
		var box := mesh_instance.global_transform * mesh_instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _update_camera() -> void:
	var width := level_aabb.size.x / zoom
	var half_width := width * 0.5
	var half_height := width * 9.0 / 32.0
	# Over the Chinook while it comes in: it is drawn at the original's scale
	# for its height, which takes it well above the usual 20 m.
	var height := TOP_CAMERA_HEIGHT
	if helicopter != null:
		height = maxf(height, helicopter.top() + 1.0)
	# The frame stays on the level: at zoom 1 it is exactly the level's width,
	# so x is pinned to the middle, as the game's camera_x is.
	focus.x = clampf(focus.x, level_aabb.position.x + half_width, level_aabb.end.x - half_width)
	focus.y = clampf(focus.y, level_aabb.position.z + half_height, level_aabb.end.z - half_height)
	if tilted:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 40.0
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		var distance := width * 1.2
		var target := Vector3(focus.x, 0.0, focus.y)
		camera.look_at_from_position(target + Vector3(0.0, distance * 0.8, distance * 0.6), target)
		camera.near = 0.5
		camera.far = 1000.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		# The top of the frame is 1.21 distances away along its ray; the map
		# spread over more than that is only coarser, stepped at the edges.
		sun.directional_shadow_max_distance = distance * 1.4
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.size = width
		camera.position = Vector3(focus.x, height, focus.y)
		camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
		camera.near = 1.0
		camera.far = height + TOP_CAMERA_HEIGHT
		# Straight down, every ground point is at the same depth, so cascades
		# buy nothing and a single map over the whole depth is sharpest.
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = height + TOP_CAMERA_HEIGHT
	_apply_shake(width)


# GameMode's songs: boss_song from the boss's trigger, which is when it arms
# and the camera starts for its arena, and nothing once it is beaten
# (mark_stage_completed's stop_song). Where the boss music follows the fight
# -- the modern mode's, Level3DAudio.ADAPTIVE -- it is told which tanks are
# on the field, a layer of it each, and the end once all four are gone: its
# victory, and in classic the stop.
func _update_music() -> void:
	var armed := boss != null and boss.camera_top() >= 0.0
	if armed and not _saw_boss:
		Level3DAudio.play_music("boss")
	_saw_boss = armed
	if armed:
		Level3DAudio.music_layers(boss.alive_layers())
	if boss != null and boss.is_defeated():
		Level3DAudio.music_end()


# The BTR's engine: idling at rest, pulling as it goes, the pull's pitch up
# with the speed. Quiet while the Chinook has it and while it is a wreck. The
# classic drive's speed jumps from nothing to top in a tick, so the mix
# follows it at ENGINE_RISE rather than jumping with it.
#
# Looked up every frame, not kept: a change of the sound's mode replaces them,
# and with no file in the mode's folder there are none.
func _update_engine_sound(delta: float) -> void:
	for c in crews:
		var idle := Level3DAudio.loop_on(c.btr, "btr_idle")
		var drive := Level3DAudio.loop_on(c.btr, "btr_drive")
		if idle == null and drive == null:
			continue
		var running := c.btr.visible and c.respawning == 0 and not c.out and chinook == null
		var ratio := clampf(absf(c.btr.speed) / c.btr.top_speed(), 0.0, 1.0) if running else 0.0
		c.engine_level = move_toward(c.engine_level, ratio, ENGINE_RISE * delta)
		if idle != null:
			idle.stream_paused = not running
			idle.volume_db = Level3DAudio.volume_db("btr_idle") + linear_to_db(1.0 - 0.7 * c.engine_level)
		if drive != null:
			drive.stream_paused = not running
			drive.volume_db = Level3DAudio.volume_db("btr_drive") + linear_to_db(maxf(c.engine_level, 0.001))
			drive.pitch_scale = 0.85 + 0.35 * c.engine_level


# The tank bench's CameraShake.Blast: two sines per axis so it does not read as
# a pendulum, a (1 - t/T)^2 envelope, over in SHAKE_TIME. In screen pixels,
# converted through the frame's width, so zoom does not change it.
const SHAKE_PIXELS := 7.0
const SHAKE_TIME := 0.55
var _shake_left := 0.0
var _shake_pixels := 0.0


# A second blast inside the first restarts it, stronger, rather than adding.
func _shake(pixels: float) -> void:
	_shake_pixels = maxf(pixels, _shake_pixels if _shake_left > 0.0 else 0.0)
	_shake_left = SHAKE_TIME


func _apply_shake(width: float) -> void:
	if _shake_left <= 0.0:
		return
	var t := SHAKE_TIME - _shake_left
	var envelope := pow(_shake_left / SHAKE_TIME, 2.0)
	var metres := _shake_pixels * width / get_viewport().get_visible_rect().size.x * envelope
	var x := sin(t * TAU * 11.0) * 0.7 + sin(t * TAU * 17.0 + 1.3) * 0.3
	var y := sin(t * TAU * 13.0 + 0.6) * 0.7 + sin(t * TAU * 19.0 + 2.1) * 0.3
	camera.position += (camera.basis.x * x + camera.basis.y * y) * metres


func _cursor_on_ground():
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + normal * 500.0))
	if hit.is_empty():
		return null
	return hit.position


func _physics_process(delta: float) -> void:
	if not _live:
		return
	_ticks += 1
	# P is a press, as a right click is; a held span presses it once. Classic
	# reads it as held instead, below.
	if not btr.classic:
		for h in _held:
			if h[0] == "rocket" and h[3] == 0 and maxi(h[1], 1) == _ticks:
				crews[0].rocket_wanted = ROCKET_WAIT
	if crews.size() > 1:
		crews[1].input.snap()
	for c in crews:
		_drive(c)
	# The firing (Level3DSettings.Firing). Classic is the game's: driving
	# classic, the gun up the screen whatever the jeep does and the grenade
	# the way it drives or faces; driving free, both along the hull. Modern
	# has both at the cursor. Combined has the launcher at the cursor and the
	# turret up the screen, however the BTR drives. The second player has no
	# cursor and fires the classic way whatever the setting.
	var cursor = null
	if _forced_aim == null and settings.firing != Level3DSettings.Firing.CLASSIC:
		cursor = _cursor_on_ground()
	for c in crews:
		_aim(c, cursor)
	for building in destructibles:
		var entry: Dictionary = destructibles[building]
		if entry.player.is_playing():
			_sync_bodies(entry)
	# The Chinook's run: Chinook sets GameMode.playing false, and the players
	# are not updated until it is over.
	if helicopter != null:
		helicopter.tick()
	var gone := {}
	for c in crews:
		gone[c] = _gone(c)
	if gone.values().all(func(g: bool): return g) and _game_over():
		return
	_hold_crews()
	for c in crews:
		if not gone[c]:
			c.btr.step(delta)
	var left_button := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not left_button:
		_gun_locked = false
	for c in crews:
		guns.acting = c
		_fire(c, gone[c], cursor, delta)
	for c in crews:
		if gone[c]:
			continue
		guns.acting = c
		if c.invincible > 0:
			c.invincible -= 1
		# Soldiers are run over and prisoners picked up whether or not the BTR is
		# invincible.
		var box := _player_box(c)
		soldiers.bump(box)
		friends.bump(box, c.carrier)
		if guns.bump(box, c.invincible > 0):
			_explode_btr(c, "ran into a gun")
		elif tanks.bump(box, c.invincible > 0):
			_explode_btr(c, "ran into a tank")
		elif boss.bump(box, c.invincible > 0):
			_explode_btr(c, "ran into a boss tank")
	# No calls before the BTR is down off the Chinook and can go to them.
	friends.held = chinook != null
	guns.tick()
	soldiers.tick()
	boats.tick()
	tanks.tick()
	boss.tick()
	tracks.tick()
	puffs.tick()
	friends.tick()
	rescue.tick()
	_show_state()
	_update_hints()
	_sync_markers()


# A player's keys onto its vehicle: the first's from the settings (and
# --hold), the second's from the 2D game's second player's mapping.
func _drive(c: Crew) -> void:
	var up := _key("up") if c.input == null else c.input.is_up() or _held_key("up", c.index)
	var down := _key("down") if c.input == null else c.input.is_down() or _held_key("down", c.index)
	var left := _key("left") if c.input == null else c.input.is_left() or _held_key("left", c.index)
	var right := _key("right") if c.input == null else c.input.is_right() or _held_key("right", c.index)
	var vehicle := c.btr
	if vehicle.classic:
		vehicle.key_up = up
		vehicle.key_down = down
		vehicle.key_left = left
		vehicle.key_right = right
		vehicle.throttle = 0.0
		vehicle.steer = 0.0
	else:
		vehicle.key_up = false
		vehicle.key_down = false
		vehicle.key_left = false
		vehicle.key_right = false
		vehicle.throttle = float(up) - float(down)
		vehicle.steer = float(left) - float(right)
	# By hand while held; let go, the aim below has the turret again, except
	# driving free with the classic firing, which leaves it where it is.
	if c.input == null:
		vehicle.turret_input = float(_turret_key("turret_left")) - float(_turret_key("turret_right"))


# Where a player's turret points (Level3DBtr.aim_point), by the firing; the
# second player's always the classic way.
func _aim(c: Crew, cursor) -> void:
	var firing := settings.firing if c.input == null else Level3DSettings.Firing.CLASSIC
	var vehicle := c.btr
	if _forced_aim != null and c.input == null:
		vehicle.aim_point = _forced_aim
	elif firing == Level3DSettings.Firing.MODERN:
		vehicle.aim_point = cursor
	elif vehicle.classic or firing == Level3DSettings.Firing.COMBINED:
		vehicle.aim_point = vehicle.position + _game_direction(270.0) * Level3DGun.RANGE
	else:
		vehicle.aim_point = null


# Player.update: while respawning the player does nothing at all; the tick
# the count runs out it comes back, invincible, and carries on -- or, with no
# life left, is out if the other player is still in (PlayerState.out). Whether
# it is gone this tick.
func _gone(c: Crew) -> bool:
	if chinook != null or c.out:
		return true
	if c.respawning == 0:
		return false
	c.respawning -= 1
	if c.respawning > 0:
		return true
	if c.lives > 0 or settings.infinite_lives:
		# Main.lose_life, as Player.update spends it: on the way back.
		if not settings.infinite_lives:
			c.lives -= 1
		c.btr.visible = true
		c.invincible = Player.INVINCIBLE_DELAY
		if guns.verbose:
			print("%dP back, invincible for %d ticks, %d lives left" % [c.index + 1, c.invincible, c.lives])
		return false
	c.out = true
	if guns.verbose:
		print("%dP out" % (c.index + 1))
	return true


# Every player out: the stage again, with GAME OVER over it. Whether it was.
func _game_over() -> bool:
	if chinook != null or crews.any(func(c: Crew): return not c.out):
		return false
	_restart()
	_banners.game_over()
	return true


# A player's gun and launcher this tick: the triggers, the aim, the weapon the
# prisoners have given.
func _fire(c: Crew, gone: bool, cursor, delta: float) -> void:
	var first := c.input == null
	var firing := settings.firing if first else Level3DSettings.Firing.CLASSIC
	var vehicle := c.btr
	var trigger := c.input.is_gun() or _held_key("gun", c.index) if not first else \
			(_hold_fire or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _gun_locked or _key("gun"))
	c.gun.trigger = not gone and trigger
	c.gun.aim_point = vehicle.aim_point
	c.gun.at_cursor = first and (_forced_aim != null or firing == Level3DSettings.Firing.MODERN and cursor != null)
	c.gun.step(delta)
	c.launcher.aim_point = vehicle.aim_point
	c.launcher.at_cursor = c.gun.at_cursor
	if not first or _forced_aim == null:
		if firing == Level3DSettings.Firing.COMBINED:
			c.launcher.aim_point = cursor
			c.launcher.at_cursor = cursor != null
		elif firing == Level3DSettings.Firing.CLASSIC and vehicle.classic:
			c.launcher.aim_point = vehicle.position \
					+ _game_direction(vehicle.classic_fire_angle()) * Level3DLauncher.RANGE
	c.launcher.has_missiles = c.carrier.has_missiles
	c.launcher.missile_power = c.carrier.missile_power
	var rocket := c.input.is_grenade() or _held_key("rocket", c.index) if not first else \
			(_key("rocket") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	# Player.update's grenade: held, it goes the tick it can, and it has to be
	# let go of between two. A press while the last one is still in the air is
	# not lost if the button is still down when it is over.
	if vehicle.classic:
		if rocket:
			if c.fire_released and not gone and c.launcher.fire():
				c.fire_released = false
				c.rockets += 1
		else:
			c.fire_released = true
	elif not first and rocket and not c.rocket_held:
		# The first player's press is an event (_unhandled_input).
		c.rocket_wanted = ROCKET_WAIT
	c.rocket_held = rocket
	# A click waits for the mount to come round and the rails to be loaded,
	# rather than being lost while they are not.
	if c.rocket_wanted > 0.0:
		c.rocket_wanted -= delta
		if not gone and c.launcher.fire():
			c.rocket_wanted = 0.0
			c.rockets += 1
	c.launcher.step(delta)


func _process(delta: float) -> void:
	Level3DWind.tick(delta)
	if not _live:
		return
	# The arrows are the second player's, with two.
	var scroll := _axis(KEY_DOWN, KEY_UP) if crews.size() == 1 else 0.0
	if scroll != 0.0:
		following = false
		focus.y -= scroll * SCROLL_SPEED / zoom * delta
	# Standing where the Chinook has it while it flies the BTR in (frame_centre):
	# the BTR stands at START unseen until the Chinook is down, then is put in
	# its cabin, and a frame following it jumped there, 6.4 m in one frame.
	# After the hand-over the frame comes on to the BTR over CATCH_UP seconds,
	# where it was not over it already. Two players, it follows the middle of
	# them (_follow_point), which keeps both in it (_hold_crews).
	if following:
		if chinook != null:
			focus = chinook.frame_centre(level_aabb.size.x / zoom * 9.0 / 32.0)
		else:
			_catch_up *= exp(-delta / CATCH_UP)
			focus = _follow_point() + _catch_up
	else:
		_catch_up = Vector2.ZERO
	# The boss's pan and the arena after it: the frame's top where the boss
	# has it, as GameMode's boss_camera_pan and max_camera_y = 0 hold it.
	var boss_top := boss.camera_top() if boss != null else -1.0
	if boss_top >= 0.0:
		focus.y = Level3DMap.to_level(Vector2(0.0, boss_top)).y + level_aabb.size.x / zoom * 9.0 / 32.0
	rescue.enlarge = not tilted
	# The game flashes the jeep through four palettes a frame while it is
	# invincible; the BTR has one, so it blinks -- the model, not its shadow
	# or its tracks (Level3DBtr.blink).
	if helicopter != null:
		helicopter.enlarge = not tilted
	else:
		for c in crews:
			if c.respawning == 0:
				c.blink = c.blink + 1 if c.invincible > 0 else 0
				c.btr.blink(c.blink % 4 < 2)
	_shake_left = maxf(_shake_left - delta, 0.0)
	_update_camera()
	Level3DAudio.listen(Vector3(focus.x, 0.0, focus.y), _view_frame())
	_update_engine_sound(delta)
	_update_music()
	_update_pad_arrow()
	_update_banners()


# Q and E, the turret by hand: fixed keys, not among the ones the menu binds
# (Level3DSettings.ACTIONS), so one of those bound to Q or E takes it from the
# turret, as the game's direction keys shadow its fallback gun keys.
func _turret_key(action: String) -> bool:
	var keycode := settings.key(action)
	return settings.action_of(keycode) == "" and Input.is_key_pressed(keycode)


# An action's key (Level3DSettings.ACTIONS) held on the keyboard, or the action
# held by --hold.
func _key(action: String) -> bool:
	return Input.is_key_pressed(settings.key(action)) or _held_key(action, 0)


# An action held by --hold for player `index`.
func _held_key(action: String, index: int) -> bool:
	for h in _held:
		if h[0] == action and h[3] == index and _ticks >= h[1] and _ticks < h[2]:
			return true
	return false


# A game angle -- 0 east, 90 down the screen -- as a level direction.
static func _game_direction(degrees: float) -> Vector3:
	var a := deg_to_rad(degrees)
	return Vector3(cos(a), 0.0, sin(a))


static func _axis(negative: Key, positive: Key) -> float:
	return (1.0 if Input.is_key_pressed(positive) else 0.0) \
			- (1.0 if Input.is_key_pressed(negative) else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _live:
		return
	# The summary waits for a press: the gun, Enter or Space, or a click.
	if _summary.shown and ((event is InputEventKey and event.pressed and not event.echo
			and event.keycode in [settings.key("gun"), KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
		_summary.dismiss()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_menu.open()
			return
		# P, unless it is rebound: a press, as a right click is. Classic reads
		# it as held instead, in _physics_process.
		if event.keycode == settings.key("rocket"):
			if not btr.classic:
				crews[0].rocket_wanted = ROCKET_WAIT
			return
		# A key bound to an action is that action's and nothing else's.
		if settings.action_of(event.keycode) != "":
			return
		match event.keycode:
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom = maxf(zoom / ZOOM_STEP, 1.0)
			KEY_EQUAL, KEY_KP_ADD:
				zoom = minf(zoom * ZOOM_STEP, 8.0)
			KEY_TAB:
				settings.camera = Level3DSettings.Camera.TOP if tilted else Level3DSettings.Camera.TILTED
				_settings_changed()
			KEY_HOME:
				following = false
				focus.y = level_aabb.end.z
			KEY_END:
				following = false
				focus.y = level_aabb.position.z
			KEY_C:
				following = true
			KEY_M:
				settings.firing = (settings.firing + 1) % Level3DSettings.Firing.size()
				_settings_changed()
				_flash_modes()
			KEY_T:
				var turbo := not gun.turbo
				for c in crews:
					c.gun.turbo = turbo
			KEY_G:
				Level3DWind.set_stepped(not Level3DWind.is_stepped())
				print("wind: ", "stepped" if Level3DWind.is_stepped() else "smooth")
			KEY_H:
				Level3DFx.real_shadows = not Level3DFx.real_shadows
				print("rockets and bombs: ", "shadows" if Level3DFx.real_shadows else "spots")
			KEY_V:
				settings.driving = Level3DSettings.Driving.FREE if btr.classic \
						else Level3DSettings.Driving.CLASSIC
				_settings_changed()
				_flash_modes()
			KEY_SPACE:
				if chinook != null:
					chinook.skip()
			KEY_R:
				_restart()
			KEY_BACKSPACE:
				btr.stop()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			# The left button is the gun's, read as held in _physics_process.
			MOUSE_BUTTON_RIGHT:
				if not btr.classic:
					crews[0].rocket_wanted = ROCKET_WAIT
			MOUSE_BUTTON_MIDDLE:
				var at = _cursor_on_ground()
				if at != null:
					btr.order(at, event.shift_pressed)
			MOUSE_BUTTON_WHEEL_UP:
				following = false
				focus.y -= 2.0 / zoom
			MOUSE_BUTTON_WHEEL_DOWN:
				following = false
				focus.y += 2.0 / zoom


# R, and the last life lost: the BTR flown in again, everything blown up
# rebuilt and every enemy back, the score and the lives as they started --
# both players', both in again.
# `jingle`: the start's intro_song, for a game from the title screen.
func _restart(jingle := false) -> void:
	_place_crews()
	following = true
	for building in destructibles:
		_set_destroyed(building, false)
	launcher.clear_craters()
	Level3DMarks.clear()
	guns.reset()
	soldiers.reset()
	boats.reset()
	tanks.reset()
	boss.reset()
	tracks.reset()
	puffs.reset()
	Level3DWind.reset()
	friends.reset()
	rescue.reset()
	map.reset()
	for c in crews:
		c.respawning = 0
		c.invincible = 0
		c.lives = EXTRA_LIVES
		c.score = 0
		c.out = false
		c.btr.visible = true
		c.btr.blink(true)
	_banners.clear()
	_summary.clear()
	_hints.clear()
	_hints_up.clear()
	_hints_off = false
	_thud = false
	_rescued_by.clear()
	_mission_from = _ticks
	_score_pops.clear()
	_saw_chinook = false
	_saw_pan = false
	_saw_defeat = false
	_saw_boss = false
	_show_state()
	# stage_song0, the Chinook's after a continue: no start jingle again.
	Level3DAudio.play_music("intro" if jingle else "stage")
	_start_intro()
	_start_flags()


# What the command line asks of every run's start, the title screen's and R's
# as well as the first: --no-chinook skips the Chinook's run, as Space does,
# the BTR simply there; --boss starts it BOSS_LEAD_ROWS below the boss's
# trigger, a few seconds' drive from the pan, with nothing behind it spawned.
const BOSS_LEAD_ROWS := 48

func _start_flags() -> void:
	var args := OS.get_cmdline_user_args()
	var to_boss := args.has("--boss")
	if (to_boss or args.has("--no-chinook")) and chinook != null:
		chinook.skip()
	if to_boss:
		_jump_to_boss()


func _jump_to_boss() -> void:
	var row := boss.trigger_row()
	if row < 0:
		push_warning("--boss: this level has no BOSS_BLUE_TANKS trigger")
		return
	# The middle-most open ground on the first row below the lead with any,
	# wide enough for every jeep side by side.
	var y := float((row + BOSS_LEAD_ROWS) * 32 + 16)
	var spread := COOP_SPREAD / Level3DMap.PX * (crews.size() - 1)
	var spot := Vector2(-1.0, -1.0)
	while spot.x < 0.0 and y < map.stage.map_height * 32:
		for i in 64:
			var x := 1024.0 + (i >> 1) * 32.0 * (1 if i & 1 else -1)
			if map.is_driveable_box(x - 48.0, y - 48.0, x + spread + 48.0, y + 48.0):
				spot = Vector2(x, y)
				break
		y += 32.0
	if spot.x < 0.0:
		push_warning("--boss: no open ground below the boss's trigger")
		return
	var at := Level3DMap.to_level(spot)
	for c in crews:
		c.btr.place(Vector3(at.x + COOP_SPREAD * c.index, 0.0, at.y), START_HEADING)
	following = true
	_catch_up = Vector2.ZERO
	focus = _follow_point()
	_update_camera()
	var top := Level3DMap.to_map(_view_frame().position).y
	soldiers.skip_to(top)
	tanks.skip_to(top)
	boats.skip_to(top)


# What the scene's collision says over the whole level, one pixel per
# OBSTACLE_STEP metres, north up: ground grey, water blue, forest green, walls
# red, trunks orange, off the level black. The BTR, its rounds and its rockets
# went by it once; they go by the game's grid now (level3d_btr.gd,
# level3d_gun.gd, level3d_rocket.gd), and this is what the ground's height and
# the look of a strike go by. Needs no window -- physics runs headless -- so it
# is the check for _add_collision:
#
#     godot --path . --headless src/tools/level3d_preview.tscn -- --obstacle-map out.png
const OBSTACLE_STEP := 0.25
const OBSTACLE_COLOURS := {
	"ground": Color(0.62, 0.58, 0.50), "water": Color(0.15, 0.35, 0.85),
	"hard": Color(0.85, 0.85, 0.85),
	"forest": Color(0.10, 0.50, 0.20), "wall": Color(0.85, 0.15, 0.10),
	"trunk": Color(1.0, 0.55, 0.0), "": Color.BLACK,
}


func _obstacle_map(path: String) -> void:
	var width := int(level_aabb.size.x / OBSTACLE_STEP)
	var height := int(level_aabb.size.z / OBSTACLE_STEP)
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	var cell := Vector3(OBSTACLE_STEP, 2.0, OBSTACLE_STEP) * 0.5
	var counts := {}
	for py in height:
		for px in width:
			var x := level_aabb.position.x + (px + 0.5) * OBSTACLE_STEP
			var z := level_aabb.position.z + (py + 0.5) * OBSTACLE_STEP
			var there := _ground_at(x, z)
			var kind: String = there.kind if there.hit else ""
			if kind == "ground" and _solid_at(Transform3D(Basis(), Vector3(x, there.height + 1.0, z)), cell):
				kind = "trunk"
			counts[kind] = counts.get(kind, 0) + 1
			image.set_pixel(px, py, OBSTACLE_COLOURS[kind])
	image.save_png(path)
	print("obstacle map %dx%d from %.2f, %.2f, %d trunks: %s" % [width, height,
			level_aabb.position.x, level_aabb.position.z, _trunks, counts])
	for building in destructibles:
		var centre: Vector3 = destructibles[building].centre
		print("  %s at %.1f, %.1f%s" % [building, centre.x, centre.z,
				" (destroyed)" if destructibles[building].destroyed else ""])
	# And the forest the other way round: what the ground under each forest
	# tree says it is. Anything but "forest" is a tree the BTR drives under.
	var under := {}
	var loose := []
	for tree in find_children("ForestTree*", "MeshInstance3D", true, false):
		var at: Vector3 = tree.global_position
		var kind: String = _ground_at(at.x, at.z).kind
		under[kind] = under.get(kind, 0) + 1
		if kind != "forest" and loose.size() < 12:
			loose.append(Vector2(snappedf(at.x, 0.1), snappedf(at.z, 0.1)))
	print("ground under forest trees: %s, e.g. %s" % [under, loose])


func _screenshot_mode() -> void:
	var args := OS.get_cmdline_user_args()
	guns.verbose = args.has("--shot")
	soldiers.verbose = guns.verbose
	boats.verbose = guns.verbose
	tanks.verbose = guns.verbose
	boss.verbose = guns.verbose
	friends.verbose = guns.verbose
	rescue.verbose = guns.verbose
	var intro := args.find("--intro")
	if intro >= 0:
		args.remove_at(intro)
	var immortal := args.find("--immortal")
	if immortal >= 0:
		_immortal = true
		args.remove_at(immortal)
	# Level3DSoldiers, Level3DBtr and Level3DAudio read these for themselves;
	# they are not waypoints.
	for own in ["--fade-corpses", "--btr", "--baked-contour", "--engine-creases", "--btr-noline", "--no-contour",
			"--no-wind", "--wind-steps", "--spots", "--audio-debug", "--editor", "--no-chinook", "--boss"]:
		var at := args.find(own)
		if at >= 0:
			args.remove_at(at)
	var free := args.find("--free")
	if free >= 0:
		settings.driving = Level3DSettings.Driving.FREE
		_apply_settings()
		args.remove_at(free)
		_show_state()
	var hold := args.find("--hold")
	if hold >= 0:
		const KEYS := {"w": "up", "a": "left", "s": "down", "d": "right", "l": "gun", "p": "rocket"}
		for span in args[hold + 1].split(","):
			# 2:wd@0-1 is the second player's.
			var index := 1 if span.begins_with("2:") else 0
			var at := span.trim_prefix("2:").split("@")
			var times := at[1].split("-")
			for c in at[0]:
				_held.append([KEYS[c], _ticks + roundi(float(times[0]) * 100.0),
						_ticks + roundi(float(times[1]) * 100.0), index])
		args = args.slice(0, hold) + args.slice(hold + 2)
	var weapon := args.find("--weapon")
	if weapon >= 0:
		var level := int(args[weapon + 1])
		crews[0].carrier.has_missiles = level > 0
		crews[0].carrier.missile_power = clampi(level - 1, 0, 2)
		args = args.slice(0, weapon) + args.slice(weapon + 2)
		_show_state()
	var aboard := args.find("--pows")
	if aboard >= 0:
		for c in crews:
			c.carrier.pows = int(args[aboard + 1])
			c.carrier.releaseable_pows = c.carrier.pows
		args = args.slice(0, aboard) + args.slice(aboard + 2)
		_show_state()
	var at_summary := args.find("--summary")
	if at_summary >= 0:
		_summary_tick = roundi(float(args[at_summary + 1]) * 100.0)
		args = args.slice(0, at_summary) + args.slice(at_summary + 2)
	var start_score := args.find("--score")
	if start_score >= 0:
		for c in crews:
			c.score = int(args[start_score + 1])
		args = args.slice(0, start_score) + args.slice(start_score + 2)
		_show_state()
	var start_at := args.find("--at")
	if start_at >= 0:
		var xz := args[start_at + 1].split(",")
		for c in crews:
			c.btr.place(Vector3(float(xz[0]) + COOP_SPREAD * c.index, 0.0, float(xz[1])), START_HEADING)
		args = args.slice(0, start_at) + args.slice(start_at + 2)
	var blow_up := args.find("--destroy")
	if blow_up >= 0:
		for building in args[blow_up + 1].split(","):
			_set_destroyed(building, true)
		args = args.slice(0, blow_up) + args.slice(blow_up + 2)
	var fire := args.find("--fire")
	if fire >= 0:
		var xz := args[fire + 1].split(",")
		_forced_aim = Vector3(float(xz[0]), 0.0, float(xz[1]))
		_hold_fire = true
		args = args.slice(0, fire) + args.slice(fire + 2)
	var rocket := args.find("--rocket")
	if rocket >= 0:
		var at := args[rocket + 1].split("@")
		var xz := at[0].split(",")
		_forced_aim = Vector3(float(xz[0]), 0.0, float(xz[1]))
		if at.size() > 1:
			get_tree().create_timer(float(at[1])).timeout.connect(func(): crews[0].rocket_wanted = INF)
		else:
			crews[0].rocket_wanted = INF
		args = args.slice(0, rocket) + args.slice(rocket + 2)
	var die := args.find("--die")
	if die >= 0:
		get_tree().create_timer(float(args[die + 1])).timeout.connect(func():
			if crews[0].respawning == 0:
				_explode_btr(crews[0], "--die"))
		args = args.slice(0, die) + args.slice(die + 2)
	for flag in ["--level", "--file", "--players", "--light"]:
		var at := args.find(flag)
		if at >= 0:
			args = args.slice(0, at) + args.slice(at + 2)  # read in _ready
	var strip := args.find("--strip")
	if strip >= 0:
		var spec := args[strip + 1].split(",")
		_strip = [int(spec[0]), float(spec[1]), int(spec[2]) if spec.size() > 2 else 512]
		args = args.slice(0, strip) + args.slice(strip + 2)
	if args.size() >= 2 and args[0] == "--obstacle-map":
		# Mapped once the ruins have settled, when anything was blown up.
		if blow_up >= 0:
			await get_tree().create_timer(DESTRUCTION_SETTLE).timeout
			await get_tree().physics_frame
			await get_tree().physics_frame
		_obstacle_map(args[1])
		get_tree().quit()
		return
	if args.size() < 2 or args[0] != "--shot":
		return
	if args.size() >= 3:
		following = false
		if args[2].contains(","):
			var xz := args[2].split(",")
			focus = Vector2(float(xz[0]), float(xz[1]))
		else:
			focus.y = lerpf(level_aabb.end.z, level_aabb.position.z, float(args[2]))
	if args.size() >= 4:
		zoom = float(args[3])
	if args.size() >= 5:
		tilted = args[4] == "tilt"
	settings.firing = Level3DSettings.Firing.CLASSIC
	if args.size() >= 6:
		for i in range(6, args.size()):
			var xz := args[i].split(",")
			btr.order(Vector3(float(xz[0]), 0.0, float(xz[1])), true)
			# A frame given as x,z stays put; one given along the stage follows.
			following = not args[2].contains(",")
		# So does one driven by --hold.
		if not _held.is_empty():
			following = not args[2].contains(",")
		await get_tree().create_timer(float(args[5])).timeout
	print("BTR at %.2f, %.2f heading %.1f, %s" % [btr.position.x, btr.position.z,
			rad_to_deg(btr.heading), "classic" if btr.classic else "free"])
	for c in crews:
		print("%dP at %.2f, %.2f heading %.1f, %d lives, %d points%s" % [c.index + 1, c.btr.position.x,
				c.btr.position.z, rad_to_deg(c.btr.heading), c.lives, c.score, ", out" if c.out else ""])

	# Shadows and the first frame's pipeline compilation need a few frames.
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if not _strip.is_empty():
		image = await _strip_sheet(image)
	var error := image.save_png(args[1])
	if error != OK:
		push_error("Cannot write %s (error %d)" % [args[1], error])
	get_tree().quit()


# --strip's sheet: the middle square of `first` and of each frame after it,
# four to a row.
func _strip_sheet(first: Image) -> Image:
	var count: int = _strip[0]
	var side: int = _strip[2]
	var columns := mini(count, 4)
	var sheet := Image.create(columns * side, ceili(count / float(columns)) * side, false, Image.FORMAT_RGBA8)
	var frame := first
	for k in count:
		if k > 0:
			await get_tree().create_timer(_strip[1]).timeout
			await RenderingServer.frame_post_draw
			frame = get_viewport().get_texture().get_image()
		frame.convert(Image.FORMAT_RGBA8)
		var middle := Rect2i((frame.get_width() - side) / 2, (frame.get_height() - side) / 2, side, side)
		sheet.blit_rect(frame, middle, Vector2i(k % columns * side, k / columns * side))
	return sheet
