# The project's main scene: a black screen with the loading sign, the
# R.A.T.E.L. emblem breathing in the corner (Level3DLoading), while the 3D
# preview (level3d_preview.tscn) loads; and then the preview. The middle of
# the screen is left empty, for something to go there later.
#
# What takes the time before the preview's first frame is not its files --
# the stage's 18 MB glb reads in under 0.1 s -- but its scripts: loading the
# scene compiles level3d_preview.gd and every class it names, and the shaders
# they preload, 1.5 s on a warm start and many more on a cold one. That is
# done here on a loader thread (load_threaded_request), the corner's emblem
# breathing meanwhile. The engine's own start, before any scene can draw, is
# black too (project.godot's boot splash, with no image).
#
# The intro's contours (Level3DBriefing.hull), 0.6 s of them, are made
# here too, while the sign breathes, so that the preview finds them made:
# HULL_BUDGET of every frame once its glb is in (HELD), on this thread --
# on one of their own they took eight seconds, every mesh read back from
# the renderer having to wait for it. Made in the intro's _init, they and
# its sheet's pictures, read there too, kept the screen black 1.5 s more.
#
# The preview's _ready then builds the title before it hands a frame back
# (Level3DTitle and its splash, ~0.4 s warm, more cold), every frame stopped
# meanwhile; so the sign goes out first and that is done on black (SIGN_OUT).
# The black lifts once the title's frames run smoothly, and the stage goes on
# being built under the title as before (Level3DPreview._breathe).
#
# HELD is loaded on the same threads and kept for the whole run (held): the
# preview and its units load() their models where they need them -- the
# stage for the title's palms, for the level and for the shop's helipad, the
# Chinook at every round -- and a model nothing holds is read and built again
# each time; held, every load() after the first finds it in the cache, and
# Level3DHull's rebuilt meshes, kept per Mesh, are found again too. The music
# likewise, every song of every sound mode, being small.
#
# Run on its own, the preview skips all this, as the level editor's Play and
# the --shot runs do:
#     godot --path . src/game3d/level3d_preview.tscn
extends Node

const MAIN := "res://src/game3d/level3d_preview.tscn"
const FADE := 0.4      # seconds, once the title is up
# The loading sign goes out over SIGN_OUT before the title is built, which
# stops every frame for ~0.4 s: on black, with nothing moving, that reads as
# a cut, where the sign stopping mid-breath read as the game hanging. The
# black then waits for the title's first frames, slow too (its stage being
# built under it, shaders compiling), to come in under SETTLED for SETTLED_RUN
# frames running, or for SETTLE_MAX at most, before it lifts.
const SIGN_OUT := 0.25
const SETTLED := 0.025     # seconds, a frame
const SETTLED_RUN := 3
const SETTLE_MAX := 1.0    # seconds
# Of every frame, seconds (_make_hulls).
const HULL_BUDGET := 0.008
# Over the preview's own layers (Level3DPreview.CRT_LAYER is the top one).
const LAYER := 100

const HELD := [
	"res://resources/3d/jackal_stage1.glb",
	"res://resources/3d/jackal_chinook.glb",
	# Level3DBtr.VEHICLES, whichever the settings pick.
	"res://resources/3d/jackal_armored.glb",
	"res://resources/3d/jackal_armored_b.glb",
	"res://resources/3d/jackal_jeep.glb",
	"res://resources/3d/ratel_btr.glb",
	"res://resources/3d/jackal_littlebird_mh6.glb",
	"res://resources/3d/low_poly_soldier.glb",
	"res://resources/3d/jackal_trooper.glb",
	"res://resources/3d/jackal_trooper_pow.glb",
	"res://resources/3d/jackal_tank.glb",
	"res://resources/3d/jackal_heavy_tank.glb",
	"res://resources/3d/jackal_boat.glb",
	"res://resources/3d/jackal_missile_bunker.glb",
	"res://resources/3d/jackal_fx_blast.glb",
	"res://resources/3d/jackal_supply.glb",
	"res://resources/3d/jackal_game_over.glb",
	"res://resources/3d/oaks/oak_001.glb",
	"res://resources/3d/oaks/oak_003.glb",
	"res://resources/3d/oaks/oak_006.glb",
	# Level3DPreview._add_destructibles: stage 1's, as the catalog lists them.
	"res://resources/3d/jackal_dest_Gate.glb",
	"res://resources/3d/jackal_dest_Barracks.glb",
	"res://resources/3d/jackal_dest_BarracksN.glb",
	"res://resources/3d/jackal_dest_BarracksN2.glb",
	"res://resources/3d/jackal_dest_BarracksN3.glb",
	"res://resources/3d/jackal_dest_Hangar_E.glb",
	"res://resources/3d/jackal_dest_Hangar_N.glb",
	"res://resources/3d/jackal_dest_Hangar_W.glb",
	"res://resources/3d/jackal_dest_BunkerGun.glb",
	# The intro's: its table and hangar (Level3DBriefing.hull's), and its
	# sheet's print and pencil, 0.4 s read where the intro was built.
	Level3DBriefing.SCENE,
	Level3DBriefing.PRINT,
	Level3DBriefing.MARKS,
]
# Level3DAudio.MUSIC_DIRS.
const MUSIC := ["res://assets/music3d/modern/", "res://assets/music3d/classic/",
		"res://assets/music3d/original/"]

var held: Array[Resource] = []

var _paths: Array[String] = []
var _layer: CanvasLayer
var _screen: Control
var _sign: Level3DLoading
var _started := false
var _hulls: Array = []          # the intro's meshes yet to have their contours
var _hulls_of: Node             # their scene, instanced for them
var _hulls_made := false


func _ready() -> void:
	# Level3DPreview.WINDOW_TITLE, from the first frame on.
	get_window().title = "R.A.T.E.L."
	# The preview pauses the tree under its title; this fades out over that.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	# All of it under one Control, to fade together.
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_screen)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(black)
	_sign = Level3DLoading.new()
	_screen.add_child(_sign)

	_paths.append(MAIN)
	_paths.append_array(HELD)
	for dir in MUSIC:
		for file in ResourceLoader.list_directory(dir):
			if file.ends_with(".ogg"):
				_paths.append(dir + file)
	for path in _paths:
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)
		else:
			push_warning("Level3DBoot: no %s to hold" % path)


func _process(_delta: float) -> void:
	_make_hulls()
	if not _started and _loaded():
		_started = true
		_start()


func _loaded() -> bool:
	if not _hulls_made:
		return false
	for path in _paths:
		if ResourceLoader.exists(path) \
				and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
	return true


# Level3DBriefing.hull for HULL_BUDGET of the frame, once its glb is in.
func _make_hulls() -> void:
	if _hulls_made:
		return
	var scene := Level3DBriefing.SCENE
	if _hulls_of == null:
		if ResourceLoader.load_threaded_get_status(scene) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		var packed := load(scene) as PackedScene
		if packed == null:
			_hulls_made = true
			return
		_hulls_of = packed.instantiate()
		for node in _hulls_of.find_children("*", "MeshInstance3D", true, false):
			if (node as MeshInstance3D).mesh != null:
				_hulls.append(node)
	var from := Time.get_ticks_usec()
	while not _hulls.is_empty() and Time.get_ticks_usec() - from < HULL_BUDGET * 1e6:
		Level3DBriefing.hull(_hulls.pop_back())
	if _hulls.is_empty():
		_hulls_of.free()
		_hulls_made = true


func _start() -> void:
	var main: PackedScene = null
	for path in _paths:
		if not ResourceLoader.exists(path):
			continue
		var resource := ResourceLoader.load_threaded_get(path)
		if resource == null:
			push_warning("Level3DBoot: %s did not load" % path)
		elif path == MAIN:
			main = resource
		else:
			held.append(resource)
	if main == null:
		push_error("Level3DBoot: cannot load %s" % MAIN)
		return
	var sign_out := create_tween()
	sign_out.tween_property(_sign, "modulate:a", 0.0, SIGN_OUT)
	await sign_out.finished
	await get_tree().process_frame
	# Its _ready runs to its first await here: the title, built and up.
	var game := main.instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	var waited := 0.0
	var run := 0
	while run < SETTLED_RUN and waited < SETTLE_MAX:
		var from := Time.get_ticks_usec()
		await get_tree().process_frame
		var frame := (Time.get_ticks_usec() - from) / 1e6
		waited += frame
		run = run + 1 if frame < SETTLED else 0
	var fade := create_tween()
	fade.tween_property(_screen, "modulate:a", 0.0, FADE)
	# Gone but for held, which this node keeps for the run.
	fade.tween_callback(_layer.queue_free)
