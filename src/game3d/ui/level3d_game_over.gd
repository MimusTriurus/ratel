# The 3D preview's game over: a soldier for every prisoner the players
# rescued, their backs to the camera, saluting the players' graves -- a cross
# for the first, a headstone for the second, with two players only -- two
# more on post beside the graves with their rifles, and up the slope behind
# them a cross for every prisoner the run did not rescue. Cannon Fodder's
# Boot Hill turned round: here the graves are the players', and as many
# stand at them as they brought home.
#
# Built from jackal_game_over.glb, which the GameOver scene of
# resources/3d/jackal_boot_hill.blend exports (export_game_over() in its
# jackal_boot_hill.py): the ground, the trees, the bushes, the rocks, the
# grass and the camera as they stand, and under Props what this places, as
# many of each as the run wants -- the two graves, the mound under them, a
# prisoner's cross. The soldiers are Kolos Studios' low poly soldier
# (low_poly_soldier.glb, CC BY 4.0, resources/3d/low_poly_soldier.txt): the
# guard without his rifle (hidden, GUARD_UNARMED) on Attention and Salute, the
# two on post with it (POST_*) on Order and Present -- one model for all, as
# the prisoners' own, which stood in the guard at first, next to them was not.
# The blend's scripts make the clips (soldier_guard.py, soldier_walk.py) and
# the glb (soldier_export.py). Where it all stands is jackal_boot_hill.py's
# layout (GRAVE_*, GUARD_*, FIELD_*), in its Blender metres turned to these:
# its (x, y, z) is (x, z, -y) here. Each thing stands on the ground under it
# (_ground_at, off the hill's own triangles).
#
# Its own world in a SubViewport, as the title's splash is (Level3DSplash3D),
# and lit its own way: soft, not the preview's two tones -- a slope's light
# runs over it smoothly, as in the picture the scene was made after, picked
# over two tones and over three (docs/preview3d.md). Its viewport carries
# SOFT_LIGHT, which the preview's _toon passes by, and its materials are
# copies with the diffuse left as Lambert's (_soften). The contour is the
# preview's (Level3DHull), on everything that has one baked: the guard, the
# graves, the crosses and the rocks; not the ground, the grass or the oaks.
#
# The trees are not the glb's: its ForestTree_* -- the stage's low-poly trees
# -- only say where a tree stands and how tall, and an oak of BlenderMCP's
# stands there instead (_plant_oaks, resources/3d/oaks/), its leafy crown
# picked over the faceted one; and its bushes, faceted too, went with them,
# looking out of place beside the oaks. Each oak is sunk into the slope down
# to the lowest ground round its trunk's foot, so that no side of the foot
# stands in the air. Its crown's palette turned green (OAK_TINT), and its
# outline drawn over the frame (_outline_oaks): a leaf is an open plane,
# which Level3DHull's shell cannot ring.
#
# And the wind in it (_add_wind): the oaks sway as the stage's trees do, by
# the stage's wind (level3d_wind.gdshaderinc, the same gusts from the same
# quarter), the trunk in a soft-lit shader (level3d_wind_soft.gdshader), the
# crown in one of its own (level3d_leaf_wind.gdshader); the grass and the
# flowers, one mesh, bend from their feet (level3d_grass_wind.gdshader), each
# vertex's height over the ground worked out on load. On its own clock, which
# runs while it is shown: the preview's, Level3DWind's, stops with the stage
# paused under it. Stepped with the stage's (Level3DWind.is_stepped); still
# under --no-wind.
#
# And it rains (`rain`, Level3DRain): the sunset that the scene was made
# under turned to a wet evening, the sun low behind the graves through a gap
# in the cloud, into the camera -- a bright band at the horizon over a dark
# sky, the guard's shadows long towards us, a cold ambient, a warm haze --
# and the drops falling through the frame, splashing at the guard's feet.
# Gloomier, as the end of a run is; and the guard against the light is
# figures, its models' faces and hands in their own shadow; and it is heard,
# Level3DAudio's ambient_rain under the music while the cemetery stands
# (RAIN_SOUND). The sunset is still there under --no-rain.
#
# And the frame an old print (`film`, level3d_game_over_film.gdshader): black
# and white, a grain, the corners dark and soft -- what hides the models up
# close here, as the light does on the title; and under the rain, drops on
# the lens (`lens_drops`, --no-drops). Gone under --no-film.
class_name Level3DGameOver
extends TextureRect

const SCENE_PATH := "res://resources/3d/jackal_game_over.glb"
const GUARD_PATH := "res://resources/3d/low_poly_soldier.glb"
# The guard's rifle, its meshes in the glb, hidden: the guard salutes.
const GUARD_UNARMED: Array[String] = ["M4", "M4_Mag"]
# The viewport's meta that _toon (level3d_preview.gd) leaves alone.
const SOFT_LIGHT := &"soft_light"

# jackal_boot_hill.py's layout, Blender metres. The graves either side of the
# aisle with two players, in it with one; the guard in two blocks either side
# of it, the first rank nearest the graves, the rest towards the camera, each
# rank filled from the aisle out; the crosses in rows up the slope.
const GRAVE_X := 0.55
const GRAVE_Y := -2.2
const GUARD_X := 1.95
const GUARD_Y := -4.9
const PER_RANK := 4
const FILE_GAP := 0.68
const RANK_GAP := 0.9
const FIELD_Y := 3.2
const FIELD_ROW := 1.5
const FIELD_GAP := 1.3
const FIELD_PER_ROW := 7
const GUARD_SCALE := 0.54    # his 1.8 m to the level's metre, as the prisoners' are
const SEED := 7

const ATTENTION := "Attention"
const SALUTE := "Salute"
const LOOP_PAD := 1.0 / 24.0  # a loop is exported to the frame before it repeats
# The guard at attention for SALUTE_FROM seconds, then saluting from the aisle
# out, SALUTE_STEP apart a file and half that a rank.
const SALUTE_FROM := 1.2
const SALUTE_STEP := 0.08
const SALUTE_BLEND := 0.12
# Lowered (lower_salute) in the same order, the salute played back, then at
# attention again, ATTENTION_BLEND into it.
const ATTENTION_BLEND := 0.2
# And at END, leaving (disperse): LEAVE_PAUSE after his hands are down a guard
# turns outward -- the left block to the left, the right to the right -- over
# TURN seconds, eased, and walks out of the frame at WALK_SPEED, the scene's
# metres a second (a man 0.97 of them tall: about the pace his walk was
# made for, a little brisker), his feet on the
# ground under him. File by file, as from a pew: the outermost first, the
# next LEAVE_FILE after, the rearmost rank first and each before it
# LEAVE_RANK later, LEAVE_JITTER at random on each. But one: the front rank's
# man at the first player's grave, who stays LAST_STAYS after the last of the
# others has turned, alone, and goes last.
const WALK := "Walk_Unarmed"
const WALK_STRIDE := 1.05     # metres a walk cycle covers, the model's (soldier_walk.py's STRIDE)
const WALK_SPEED := 0.62
const WALK_BLEND := 0.3
const TURN := 0.8
const LEAVE_PAUSE := 0.3
const LEAVE_FILE := 0.45
const LEAVE_RANK := 0.35
const LEAVE_JITTER := 0.25
const LAST_STAYS := 2.0
# And at CONTINUE, help coming (reinforce): the hands down, and a Chinook
# heard coming in from behind the camera, over the guard and the graves --
# low, its rotors' wash taking the wind in the grass and the oaks up to
# HELP_WIND times its strength as it passes over -- and away across the
# slope to the side, HELP_HEADING off straight ahead, smaller, until it sinks
# behind the ground's crest on that line. From HELP_FLY's start to its end
# along a curve over those (_help_path), at the stage's size for it beside
# the guard (HELP_SIZE), its rotors turning (Level3DChinook.split_clips),
# nose first; heard as near as it is
# (HELP_HEARD metres at full, less as it goes, in over HELP_SOUND_IN at the
# start). From HELP_COLOUR_AT the print's colour comes back over
# HELP_COLOUR_IN, as the BTR's run comes again, out of the Chinook. HELP_FOR
# seconds, then the screen's black, the sound going with it; a key at the
# screen cuts it short. Long: the player who has seen it skips it.
const HELP_MODEL := "res://resources/3d/jackal_chinook.glb"
const HELP_SOUND := "chinook"
# The stage's Chinook is at the BTR's scale, Level3DBtr.MODEL_SCALE, against
# the soldiers' 0.55 (Level3DFriends.MODEL): some nine soldiers long, not the
# real one's sixteen -- the size the player knows it by. Here the soldiers are
# at GUARD_SCALE, and it at the same share of that.
const HELP_SIZE := 0.31 / 0.55
const HELP_FLY := Vector2(0.6, 10.5)
# Its curve's points, along HELP_HEADING (degrees from straight ahead, to the
# right) from the middle of the cemetery: behind and over the camera, a
# little to the other side (HELP_START); HELP_OVER along, above the frame's
# top -- the sky over the hill in the frame is a narrow band, which a
# Chinook fills only well off -- then HELP_PAST past the crest on its line
# and HELP_CLEAR over it; its end HELP_BEHIND past the crest and under it.
const HELP_HEADING := 20.0
const HELP_START := Vector3(-3.0, 9.0, 16.0)
const HELP_OVER := Vector2(10.0, 10.0)        # along, height
const HELP_CLEAR := 7.0
const HELP_PAST := 10.0
const HELP_BEHIND := Vector2(40.0, 5.0)
const HELP_HEARD := 10.0
const HELP_SOUND_IN := 1.5
const HELP_WIND := 4.0
const HELP_WASH := 22.0       # how far off its wash reaches the plants, metres
const HELP_COLOUR_AT := 4.5
const HELP_COLOUR_IN := 2.5
const HELP_FOR := 9.0
# The posts: two soldiers with their rifles, one either side of the graves,
# facing in across them -- seen from the side, the rifle against the sky --
# at POST_AT (x off the middle, y; Blender metres, as the layout's), in the
# gap between the guard's blocks: four, in a row, by the graves' corners or
# one behind the other, hid each other and stood behind the guard's inner
# files. At order arms (Order, the blend's soldier_guard.py), presenting arms
# (Present) with the guard's first salute and holding it from then on: when
# the guard lowers its hands, and at END, when it goes and they stay on post.
# His 1.8 m at the prisoners' scale.
const POST_ORDER := "Order"
const POST_PRESENT := "Present"
const POST_AT := Vector2(1.1, GRAVE_Y + 0.2)
# The ranks the camera takes in as it stands; a block deeper than that (one
# player who brought most of them home) and it steps back BACK_PER_RANK for
# each more, or the last ranks would stand behind it. Twice a rank's depth:
# back one only, the nearest rank stood as close as before and as big, and
# hid the graves.
const RANKS_IN_FRAME := 3
const BACK_PER_RANK := 1.8

# The GameOver scene's light, in its Blender values, linear: a low warm sun
# from behind the camera's left (its rotation 64, 0, -35 degrees) and a warm
# ambient. Blender's sun of 2.8 W/m2 lights a white Lambert face at 2.8 / pi;
# Godot's light_energy is that face's brightness.
const SUN_TRAVEL := Vector3(0.5155, -0.4384, -0.7363)   # Blender's (0.516, 0.736, -0.438)
const SUN_COLOUR := Color(1.0, 0.80, 0.58)
const SUN_ENERGY := 2.8 / PI
const AMBIENT := Color(0.95, 0.62, 0.42)
const AMBIENT_ENERGY := 0.5
# Compatibility, which the project renders with, lights the same scene about
# 2.2 times as bright as those energies say: measured, the headstone's lit
# face at 215,182,146 against Blender's 151,130,105 (tools/game_over_shot.gd
# against the test scene's render). And it reads the vertices' colours as
# sRGB: the ground's, linear from Blender, came out near black in its blue.
const LIGHT_GAIN_COMPATIBILITY := 1.0 / 2.2
const SHADOW_DISTANCE := 45.0
# A dusk from warm at the horizon to blue overhead, as the test scene's world
# drew it (_dusk). The Compatibility renderer takes a sky's colour as sRGB as
# it is, so these are sRGB.
const SKY_SHADER := """
shader_type sky;

uniform vec3 HORIZON = vec3(1.0, 0.77, 0.57);
uniform vec3 ROSE = vec3(0.93, 0.70, 0.70);
uniform vec3 HIGH = vec3(0.51, 0.58, 0.81);

void sky() {
	float up = EYEDIR.y;
	vec3 c = mix(HORIZON, ROSE, smoothstep(0.0, 0.14, up));
	c = mix(c, HIGH, smoothstep(0.14, 0.36, up));
	COLOR = up < 0.0 ? HORIZON : c;
}
"""

# The rain's light, in place of the sunset's (the header): the sky's three
# bands, sRGB, a warm bright horizon under a slate one; the sun low from
# behind the graves into the camera (RAIN_SUN_TRAVEL), RAIN_SUN times the
# sunset's energy, its shadows near full; the ambient cold and low, so that
# what the sun does not reach is dark; a haze RAIN_FOG thick, the horizon's
# colour, thin enough that the crosses up the slope still show.
const RAIN_SKY: Array[Vector3] = [Vector3(1.0, 0.86, 0.66), Vector3(0.70, 0.64, 0.62), Vector3(0.30, 0.32, 0.38)]
const RAIN_SUN_TRAVEL := Vector3(0.3, -0.16, 0.94)
const RAIN_SUN := 2.5
const RAIN_SUN_COLOUR := Color(1.0, 0.82, 0.62)
const RAIN_SHADOW := 0.9
const RAIN_AMBIENT := Color(0.42, 0.46, 0.58)
const RAIN_AMBIENT_ENERGY := 0.45
const RAIN_FOG := 0.024
const RAIN_FOG_COLOUR := Color(0.78, 0.70, 0.62)
# Where the drops start, the scene's metres: over the frame from the hill's
# crest to 3 m short of the camera -- nearer, a drop crossed the lens as a
# thick white bar; further off they are under a pixel, and the haze is the
# rain there. The ground the splashes come off, x and z, round the guard and
# the graves.
const RAIN_BOX := AABB(Vector3(-12.0, 3.0, -16.0), Vector3(24.0, 9.0, 22.0))
const SPLASH_AREA := Rect2(-7.0, -6.0, 14.0, 14.0)
static var rain := true
# The rain heard (the header), in over RAIN_SOUND_IN seconds; the screen
# fades it with its song (fade_rain).
const RAIN_SOUND := "ambient_rain"
const RAIN_SOUND_IN := 1.5
var _wet := false
var _rain_sound: AudioStreamPlayer
var _rain_fade: Tween
var _help_from := INF         # _time CONTINUE was picked at, INF until it is
var _help: Node3D             # the Chinook
var _help_path: Array[Vector3] = []   # its curve's four points
var _help_leave := 0.6        # the screen's black's, which the sound goes with
var _help_sound: AudioStreamPlayer
var _help_fade: Tween

# The old print over the frame (the header). The players' helmets on their
# graves kept their colours under it for a while, keyed in the oaks' mask;
# the helmets went, at the user's word, and the keying with them.
const FILM_SHADER := preload("res://src/game3d/shaders/level3d_game_over_film.gdshader")
static var film := true
# The rain's drops on the lens, in the print (level3d_game_over_film.gdshader):
# under the rain only, and not under --no-drops.
static var lens_drops := true
var _wet_lens := false
var _film: ShaderMaterial

var viewport: SubViewport
var shown := false

var _world: Node3D
var _camera: Camera3D
var _camera_rest := Transform3D.IDENTITY   # where the glb has it
var _templates := {}         # Prop_* name -> its node, out of the tree
var _guard_scene: PackedScene
# {player: AnimationPlayer, presenting}
var _posts: Array[Dictionary] = []
var _ground_mesh: TriangleMesh
var _ground_xform := Transform3D.IDENTITY
var _soft := {}              # a glb's material -> its soft copy
var _placed: Array[Node3D] = []   # this run's graves, mounds, crosses and guard
# {node, player: AnimationPlayer, at: seconds, saluting, down: seconds or INF,
# lowered, out: -1 or 1 the way he leaves, file, rank, last: the one who stays,
# leave: seconds or INF, walking, gone}
var _guard: Array[Dictionary] = []
var _time := 0.0

const WIND_SOFT_SHADER := preload("res://src/game3d/shaders/level3d_wind_soft.gdshader")
const GRASS_WIND_SHADER := preload("res://src/game3d/shaders/level3d_grass_wind.gdshader")
const LEAF_WIND_SHADER := preload("res://src/game3d/shaders/level3d_leaf_wind.gdshader")
# BlenderMCP's oaks (pipeline/tree_gen.py there), each with its tree.json:
# three of its six, turn and turn about. Its root plate is under its board's
# ground and its twigs show only once the crown has burnt, so neither is
# drawn here.
const OAK_PATHS: Array[String] = ["res://resources/3d/oaks/oak_001.glb", "res://resources/3d/oaks/oak_003.glb",
		"res://resources/3d/oaks/oak_006.glb"]
const OAK_DROPPED: Array[String] = ["TreeGame.Twig", "TreeGame.Soil", "TreeGame.Root"]
# An oak this much taller than the tree whose place it takes, and turned
# OAK_TURN radians from the one before.
const OAK_GROW := 1.15
const OAK_TURN := 1.3
# The trunk's foot: how far up the bark it is measured, metres of the model,
# and how far under the lowest ground round it it is sunk, metres.
const OAK_FOOT := 0.3
const OAK_SINK := 0.05
# How much an oak gives to the wind, as a share of what a palm does on the
# stage: its model is in real metres, 7 m tall, and the wind bends by the
# square of the height, so a little goes a long way -- its top some 0.3 m.
const OAK_GIVE := 0.3
# The crown's colour, linear, per channel: the palette was picked for
# BlenderMCP's board light, and under this low warm sun came out olive-brown,
# 41,38,5 on average -- the grass's colour, darker. Turned to a green between
# the stage's trees' and the uniforms': 27,66,28 on average, measured.
const OAK_TINT := Vector3(0.75, 1.55, 2.2)

# The oaks' outline (_outline_oaks): the originals on OAK_LAYER, which the
# mask's camera does not see, their doubles on MASK_LAYER, which the scene's
# camera does not.
const OAK_MASK_SHADER := preload("res://src/game3d/shaders/level3d_oak_mask.gdshader")
const OAK_INK_SHADER := preload("res://src/game3d/shaders/level3d_oak_ink.gdshader")
const OAK_LAYER := 1 << 1
const MASK_LAYER := 1 << 2
# The rain's, which the mask's camera leaves out as well: a drop over a crown
# would cut the crown in the mask, and ink every streak across it.
const RAIN_LAYER := 1 << 3
var _mask: SubViewport
var _fog_density := 0.0          # the rain's haze, 0 without it: the oaks' ink is hazed by it too
var _mask_camera: Camera3D
var _wind: Array[ShaderMaterial] = []
var _wind_made := {}         # a mesh -> its surfaces' wind materials, null where none
var _wind_clock := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	viewport.set_meta(SOFT_LIGHT, true)
	add_child(viewport)
	texture = viewport.get_texture()
	_guard_scene = load(GUARD_PATH)
	# The oaks' mask (_outline_oaks): the same world from the same camera,
	# without the smoothing, which would blend an oak's colour into its
	# neighbours'.
	_mask = SubViewport.new()
	_mask.world_3d = viewport.find_world_3d()
	_mask.msaa_3d = Viewport.MSAA_DISABLED
	_mask.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_mask.set_meta(SOFT_LIGHT, true)
	add_child(_mask)
	_rain_sound = AudioStreamPlayer.new()
	add_child(_rain_sound)
	_help_sound = AudioStreamPlayer.new()
	add_child(_help_sound)
	_mask_camera = Camera3D.new()
	_mask_camera.cull_mask = 0xFFFFF & ~OAK_LAYER & ~RAIN_LAYER
	_mask.add_child(_mask_camera)
	_build()
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for template in _templates.values():
			(template as Node).free()


func _build() -> void:
	_world = Node3D.new()
	viewport.add_child(_world)

	var sky_shader := Shader.new()
	sky_shader.code = SKY_SHADER
	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	var wet := rain and not OS.get_cmdline_user_args().has("--no-rain")
	_wet = wet
	if wet:
		sky_material.set_shader_parameter("HORIZON", RAIN_SKY[0])
		sky_material.set_shader_parameter("ROSE", RAIN_SKY[1])
		sky_material.set_shader_parameter("HIGH", RAIN_SKY[2])
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# The light is the sun's and the ambient colour's, not the sky's.
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var gain := LIGHT_GAIN_COMPATIBILITY if _is_compatibility() else 1.0
	environment.ambient_light_color = (RAIN_AMBIENT if wet else AMBIENT).linear_to_srgb()
	environment.ambient_light_energy = (RAIN_AMBIENT_ENERGY if wet else AMBIENT_ENERGY) * gain
	if wet:
		environment.fog_enabled = true
		environment.fog_light_color = RAIN_FOG_COLOUR
		environment.fog_density = RAIN_FOG
		_fog_density = RAIN_FOG
		environment.fog_sky_affect = 0.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.light_color = (RAIN_SUN_COLOUR if wet else SUN_COLOUR).linear_to_srgb()
	sun.light_energy = SUN_ENERGY * gain * (RAIN_SUN if wet else 1.0)
	if wet:
		sun.shadow_opacity = RAIN_SHADOW
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	sun.basis = Basis.looking_at((RAIN_SUN_TRAVEL if wet else SUN_TRAVEL).normalized(), Vector3.UP)
	_world.add_child(sun)
	_wet_lens = wet and lens_drops and not OS.get_cmdline_user_args().has("--no-drops")
	if film and not OS.get_cmdline_user_args().has("--no-film"):
		_add_film()

	var scene := (load(SCENE_PATH) as PackedScene).instantiate() as Node3D
	var props := scene.find_child("Props", true, false)
	for child in props.get_children():
		props.remove_child(child)
		_soften(child)
		_templates[String(child.name)] = child
	props.get_parent().remove_child(props)
	props.free()
	var hill := scene.find_child("GO_Hill", true, false) as MeshInstance3D
	if _is_compatibility():
		_colours_to_srgb(hill)
	# The rain's sun is some 9 degrees up: the hill's facets, each a ridge to
	# it, threw shadows tens of metres long with straight edges across the
	# graves' ground, which read as nothing in the scene. Lit by it still.
	if wet:
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_mesh = hill.mesh.generate_triangle_mesh()
	_ground_xform = _transform_in(hill, scene)
	_soften(scene)
	_plant_oaks(scene)
	_add_wind(scene)
	if wet:
		var weather := Level3DRain.new()
		weather.build(RAIN_BOX, SPLASH_AREA, func(x: float, z: float) -> float: return _ground_at(x, -z), RAIN_LAYER)
		_world.add_child(weather)
	_world.add_child(scene)
	_camera = scene.find_child("GO_Camera*", true, false) as Camera3D
	if _camera != null:
		_camera.current = true
		_camera.cull_mask = 0xFFFFF & ~MASK_LAYER
		_camera_rest = _camera.transform
		_mask_camera.current = true


static func _is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


# The mesh's vertex colours, linear as Blender wrote them, turned to sRGB,
# which is how Compatibility reads them (LIGHT_GAIN_COMPATIBILITY).
static func _colours_to_srgb(instance: MeshInstance3D) -> void:
	var source := instance.mesh as ArrayMesh
	var out := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var colours := arrays[Mesh.ARRAY_COLOR] as PackedColorArray
		for i in colours.size():
			colours[i] = colours[i].linear_to_srgb()
		arrays[Mesh.ARRAY_COLOR] = colours
		out.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		out.surface_set_material(surface, source.surface_get_material(surface))
		out.surface_set_name(surface, source.surface_get_name(surface))
	instance.mesh = out


# A node's transform in `root`'s space, before either is in the tree.
static func _transform_in(node: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != root and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


# Every mesh under `root`: its contour (Level3DHull), and its materials as
# soft copies -- Lambert's diffuse, which the preview's _toon may already have
# stepped on the glb's own (what the stage loads too), and no
# specular, as the scene was drawn in Blender. The ground takes its colours
# from its vertices. The contour's material is left as it is.
func _soften(root: Node, kind := Level3DHull.Kind.STAGE) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var instance := node as MeshInstance3D
		Level3DHull.apply(instance, kind)
		var mesh := instance.mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var base := mesh.surface_get_material(surface) as BaseMaterial3D
			if base == null or base.resource_name.ends_with("Contour"):
				continue
			if not _soft.has(base):
				var copy := base.duplicate() as BaseMaterial3D
				copy.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
				copy.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				copy.roughness = 1.0
				copy.metallic = 0.0
				copy.metallic_specular = 0.0
				if mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
					copy.vertex_color_use_as_albedo = true
				_soft[base] = copy
			instance.set_surface_override_material(surface, _soft[base])


# The ground's height at Blender's (x, y): where a ray down meets the hill.
func _ground_at(x: float, y: float) -> float:
	var inverse := _ground_xform.affine_inverse()
	var hit := _ground_mesh.intersect_ray(inverse * Vector3(x, 100.0, -y), inverse.basis * Vector3.DOWN)
	if hit.is_empty():
		return 0.0
	return (_ground_xform * (hit["position"] as Vector3)).y


# A thing at Blender's (x, y) on the ground, turned `yaw` about the up axis and
# `tilt` about x, both radians, as Blender's turns are (they carry over: its
# Z is this Y, its X this X).
func _put(node: Node3D, x: float, y: float, yaw := 0.0, tilt := 0.0) -> Node3D:
	node.position = Vector3(x, _ground_at(x, y), -y)
	node.rotation = Vector3(tilt, yaw, 0.0)
	_world.add_child(node)
	_placed.append(node)
	return node


# The run's end: `rescued` each player's rescued prisoners (one entry for one
# player, two for two), `total` the prisoners there were; the rest are the
# crosses. The guard comes to attention and salutes (_process), and lowers
# its hands at the player's pick, CONTINUE or END (lower_salute).
func show_game_over(rescued: Array, total: int) -> void:
	clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var players := clampi(rescued.size(), 1, 2)
	# The graves, the first's a cross and the second's a headstone, each on a
	# fresh mound towards the guard.
	var xs: Array[float] = [0.0]
	if players == 2:
		xs = [-GRAVE_X, GRAVE_X]
	for p in players:
		_put((_templates["Prop_Grave_%dP" % (p + 1)] as Node3D).duplicate(), xs[p], GRAVE_Y)
		var mound := (_templates["Prop_Mound"] as Node3D).duplicate() as Node3D
		var keep := mound.scale
		_put(mound, xs[p], GRAVE_Y)
		mound.scale = keep
	# The guard: either player's rescued in a block of his own, or one
	# player's in two halves.
	var first := int(rescued[0])
	var blocks: Array[int] = [(first + 1) / 2, first / 2]
	if players == 2:
		blocks = [first, int(rescued[1])]
	if _camera != null:
		var ranks := ceili(maxi(blocks[0], blocks[1]) / float(PER_RANK))
		var back := maxi(ranks - RANKS_IN_FRAME, 0) * BACK_PER_RANK
		_camera.transform = _camera_rest.translated_local(Vector3(0.0, 0.0, back))
	for b in 2:
		var middle := -GUARD_X if b == 0 else GUARD_X
		var outward := -1.0 if b == 0 else 1.0
		for i in blocks[b]:
			var rank := i / PER_RANK
			var file := i % PER_RANK
			var x := middle + outward * (file - (PER_RANK - 1) * 0.5) * FILE_GAP
			var guard := _guard_scene.instantiate() as Node3D
			for gun in GUARD_UNARMED:
				var mesh := guard.find_child(gun, true, false) as Node3D
				if mesh != null:
					mesh.visible = false
			_soften(guard, Level3DHull.Kind.PEOPLE)
			guard.scale = Vector3.ONE * GUARD_SCALE
			_put(guard, x, GUARD_Y - rank * RANK_GAP, PI + deg_to_rad(rng.randf_range(-3.0, 3.0)))
			guard.scale = Vector3.ONE * GUARD_SCALE
			_stand(guard, rng, SALUTE_FROM + (file + rank * 0.5) * SALUTE_STEP)
			if not _guard.is_empty() and _guard.back().node == guard:
				_guard.back().merge({"out": outward, "file": file, "rank": rank,
						"last": b == 0 and i == 0}, true)
	_post_soldiers(rng)
	# The ones not rescued: crosses in rows up the slope behind.
	var lost := maxi(total - _sum(rescued), 0)
	for i in lost:
		var row := i / FIELD_PER_ROW
		var in_row := mini(lost - row * FIELD_PER_ROW, FIELD_PER_ROW)
		var x := (i % FIELD_PER_ROW - (in_row - 1) * 0.5) * FIELD_GAP + rng.randf_range(-0.12, 0.12)
		var y := FIELD_Y + row * FIELD_ROW + rng.randf_range(-0.1, 0.1)
		_put((_templates["Prop_Cross"] as Node3D).duplicate(), x, y,
				deg_to_rad(rng.randf_range(-6.0, 6.0)), deg_to_rad(rng.randf_range(-3.0, 3.0)))
	_time = 0.0
	shown = true
	visible = true
	# Deferred: built for a screen the tree has not taken in yet, it cannot
	# play.
	_start_rain_sound.call_deferred()


static func _sum(values: Array) -> int:
	var total := 0
	for v in values:
		total += int(v)
	return total


# A guard to attention, breathing from a phase of his own, to salute at `at`.
func _stand(guard: Node3D, rng: RandomNumberGenerator, at: float) -> void:
	var player := guard.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	var attention := player.get_animation(ATTENTION)
	# The clip is the glb's, shared: looped once.
	if not attention.has_meta(&"looped"):
		attention.length += LOOP_PAD
		attention.loop_mode = Animation.LOOP_LINEAR
		attention.set_meta(&"looped", true)
	player.play(ATTENTION)
	player.seek(rng.randf() * attention.length, true)
	_guard.append({"node": guard, "player": player, "at": at, "saluting": false, "down": INF, "lowered": false,
			"out": 1.0, "file": 0, "rank": 0, "last": false, "leave": INF, "walking": false, "gone": false})


# The posts (POST_*): either side, facing in.
func _post_soldiers(rng: RandomNumberGenerator) -> void:
	for side in [-1.0, 1.0]:
		for at in [POST_AT]:
			var post := _guard_scene.instantiate() as Node3D
			_soften(post, Level3DHull.Kind.PEOPLE)
			post.scale = Vector3.ONE * GUARD_SCALE
			_put(post, side * at.x, at.y, -side * PI * 0.5 + deg_to_rad(rng.randf_range(-2.0, 2.0)))
			post.scale = Vector3.ONE * GUARD_SCALE
			var player := post.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if player == null:
				continue
			var order := player.get_animation(POST_ORDER)
			if not order.has_meta(&"looped"):
				order.length += LOOP_PAD
				order.loop_mode = Animation.LOOP_LINEAR
				order.set_meta(&"looped", true)
			player.play(POST_ORDER)
			player.seek(rng.randf() * order.length, true)
			_posts.append({"player": player, "presenting": false})


# The guard's hands down, CONTINUE or END picked at the end (the screen's
# menu): from the aisle out, as they went up; one that had not saluted yet
# stays at attention.
func lower_salute() -> void:
	for g in _guard:
		if not g.saluting:
			g.saluting = true
			g.lowered = true
		elif g.down == INF:
			g.down = _time + float(g.at) - SALUTE_FROM


# END picked (the screen): the hands down, and the guard leaving (the
# constants' note). The seconds from now till the last of them turns to go,
# 0 with no guard.
func disperse() -> float:
	lower_salute()
	if _guard.is_empty():
		return 0.0
	var salute := (_guard[0].player as AnimationPlayer).get_animation(SALUTE).length
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var last: Dictionary = {}
	var ranks := 0
	for g in _guard:
		ranks = maxi(ranks, int(g.rank) + 1)
		if g.last:
			last = g
	# No guard at the first grave (the first player brought none home): the
	# second's nearest stays.
	if last.is_empty():
		last = _guard[0]
	var latest := _time
	for g in _guard:
		var down: float = g.down if g.down != INF else _time - salute
		g.leave = maxf(down + salute, _time) + LEAVE_PAUSE + (PER_RANK - 1 - int(g.file)) * LEAVE_FILE \
				+ (ranks - 1 - int(g.rank)) * LEAVE_RANK + rng.randf() * LEAVE_JITTER
		if g != last:
			latest = maxf(latest, g.leave)
	last.leave = maxf(latest, float(last.leave)) + LAST_STAYS
	return float(last.leave) - _time


# A guard leaving (disperse): turning outward over TURN, walking from his
# first step, faster as he comes round; gone once he is out of the frame.
func _leave(g: Dictionary, delta: float) -> void:
	var node := g.node as Node3D
	var player := g.player as AnimationPlayer
	if not g.walking:
		g.walking = true
		g.from_yaw = node.rotation.y
		var walk := player.get_animation(WALK)
		# The clip is the glb's, shared by the guard and the stage's prisoners
		# (Level3DFriends.loop_clips): looped once.
		if not walk.has_meta(&"looped"):
			walk.length += LOOP_PAD
			walk.loop_mode = Animation.LOOP_LINEAR
			walk.set_meta(&"looped", true)
		player.play(WALK, WALK_BLEND)
		player.speed_scale = WALK_SPEED * walk.length / (WALK_STRIDE * GUARD_SCALE)
	var turned := smoothstep(0.0, 1.0, clampf((_time - float(g.leave)) / TURN, 0.0, 1.0))
	node.rotation.y = lerp_angle(float(g.from_yaw), float(g.out) * PI * 0.5, turned)
	node.position.x += float(g.out) * WALK_SPEED * turned * delta
	node.position.y = _ground_at(node.position.x, -node.position.z)
	# His trailing shoulder, a man's height up, out of the frame too.
	var behind := node.position + Vector3(-float(g.out) * 0.3, 0.9, 0.0)
	if _camera != null and turned >= 1.0 and not _camera.is_position_in_frustum(behind) \
			and not _camera.is_position_in_frustum(node.position + Vector3(-float(g.out) * 0.3, 0.0, 0.0)):
		g.gone = true
		node.visible = false
		player.stop()


# CONTINUE picked (the screen): help coming (the constants' note). The
# seconds it takes before the screen goes to black over `leave`, which the
# rotors' sound goes with.
func reinforce(leave: float) -> float:
	lower_salute()
	_help_from = _time
	_help_leave = leave
	var model := load(HELP_MODEL) as PackedScene
	if model != null:
		_help = model.instantiate() as Node3D
		_help.scale = Vector3.ONE * GUARD_SCALE * HELP_SIZE
		_soften(_help)
		# Against the light, a dark shape: the haze would have it a pale
		# ghost of the hill's colour at the distance it is seen at.
		for node in _help.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			for surface in instance.get_surface_override_material_count():
				var material := instance.get_surface_override_material(surface) as BaseMaterial3D
				if material != null:
					material.disable_fog = true
		_world.add_child(_help)
		Level3DChinook.split_clips(_help)
		_help_path = _help_course()
		_place_help()
	var sound := Level3DAudio.stream(HELP_SOUND)
	if sound != null:
		_help_sound.stream = sound
		_help_sound.bus = Level3DAudio.bus(HELP_SOUND)
		_help_sound.volume_db = Level3DAudio.SILENT_DB
		_help_sound.play()
	if _film != null:
		_help_fade = create_tween()
		_help_fade.tween_interval(HELP_COLOUR_AT)
		_help_fade.tween_method(func(f: float): _film.set_shader_parameter("fade", f), 1.0, 0.0, HELP_COLOUR_IN) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return HELP_FOR


# A node's meshes' box, in its own space.
static func _aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var b := _transform_in(instance, root) * instance.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# The Chinook's curve (the constants' note): its crest the highest ground on
# its line.
func _help_course() -> Array[Vector3]:
	var a := deg_to_rad(HELP_HEADING)
	var way := Vector3(sin(a), 0.0, -cos(a))
	var crest := Vector2(0.0, -INF)   # (along, height)
	var along := 0.0
	while along < 150.0:
		var p := way * along
		var h := _ground_at(p.x, -p.z)
		if h > crest.y:
			crest = Vector2(along, h)
		along += 1.0
	var over := way * HELP_OVER.x + Vector3.UP * HELP_OVER.y
	var over_crest := way * (crest.x + HELP_PAST) + Vector3.UP * (crest.y + HELP_CLEAR)
	var behind := way * (crest.x + HELP_BEHIND.x) + Vector3.UP * (crest.y - HELP_BEHIND.y)
	return [HELP_START, over, over_crest, behind]


# The Chinook where it is on its curve now, nose along it, its wash and its
# sound as near as it is.
func _place_help() -> void:
	var e := _time - _help_from
	var u := clampf((e - HELP_FLY.x) / (HELP_FLY.y - HELP_FLY.x), 0.0, 1.0)
	# Quick over the camera, slowing as it goes away.
	u = 1.0 - pow(1.0 - u, 1.3)
	var at := _bezier(u)
	var ahead := _bezier(minf(u + 0.01, 1.0)) - at
	_help.position = at
	if ahead.length_squared() > 1e-8 and u < 1.0:
		# The model's nose is its +z.
		_help.basis = Basis.looking_at(ahead.normalized(), Vector3.UP, true).scaled(_help.scale)
	var near := (at - Vector3(0.0, 1.0, 3.0)).length()
	_set_wind_strength(1.0 + (HELP_WIND - 1.0) * clampf(1.0 - near / HELP_WASH, 0.0, 1.0))
	if _help_sound.playing:
		var gain := clampf(HELP_HEARD / maxf(near, 0.1), 0.0, 1.0) * clampf(e / HELP_SOUND_IN, 0.0, 1.0)
		gain *= clampf(1.0 - (e - HELP_FOR) / _help_leave, 0.0, 1.0)
		_help_sound.volume_db = Level3DAudio.volume_db(HELP_SOUND) + linear_to_db(maxf(gain, 0.0001))


func _bezier(u: float) -> Vector3:
	var p := _help_path
	var v := 1.0 - u
	return p[0] * v * v * v + p[1] * 3.0 * v * v * u + p[2] * 3.0 * v * u * u + p[3] * u * u * u


func clear() -> void:
	_rain_sound.stop()
	_help_sound.stop()
	if _help_fade != null:
		_help_fade.kill()
		_help_fade = null
	if _help != null:
		_help.queue_free()
		_help = null
	if _help_from != INF:
		_help_from = INF
		_set_wind_strength(1.0)
		if _film != null:
			_film.set_shader_parameter("fade", 1.0)
	for node in _placed:
		node.queue_free()
	_placed.clear()
	_guard.clear()
	_posts.clear()
	shown = false
	visible = false


func _process(delta: float) -> void:
	if not shown:
		return
	# The render the size of the frame it fills, in the screen's pixels, not
	# the frame's (Level3DPixels): blown up, its edges stepped. Smoothed as
	# the settings say, the oaks' mask never.
	var want := Vector2i(size * Level3DPixels.scale(self))
	viewport.msaa_3d = Level3DPixels.msaa
	if want.x > 0 and want.y > 0 and viewport.size != want:
		viewport.size = want
		_mask.size = want
	if _camera != null:
		_mask_camera.global_transform = _camera.global_transform
		_mask_camera.fov = _camera.fov
		_mask_camera.near = _camera.near
		_mask_camera.far = _camera.far
		_mask_camera.keep_aspect = _camera.keep_aspect
	_time += delta
	_wind_clock += delta
	if _film != null:
		_film.set_shader_parameter("time", _time)
	for material in _wind:
		material.set_shader_parameter("wind_clock", _wind_clock)
	if _help_from != INF and _help != null:
		_place_help()
	for g in _guard:
		var player := g.player as AnimationPlayer
		if g.gone:
			continue
		if _time >= g.leave:
			_leave(g, delta)
		elif not g.saluting and _time >= g.at:
			player.play(SALUTE, SALUTE_BLEND)
			g.saluting = true
		elif not g.lowered and _time >= g.down:
			player.play_backwards(SALUTE)
			g.lowered = true
		elif g.lowered and g.down != INF and _time >= g.down + player.get_animation(SALUTE).length:
			player.play(ATTENTION, ATTENTION_BLEND)
			g.down = INF
	# The posts present arms with the guard's first salute, and hold it.
	for p in _posts:
		if not p.presenting and _time >= SALUTE_FROM:
			(p.player as AnimationPlayer).play(POST_PRESENT, SALUTE_BLEND)
			p.presenting = true


# The rain heard, from nothing: the stream asked for again each time, as the
# sound mode may have changed since (none in ORIGINAL).
func _start_rain_sound() -> void:
	_rain_sound.stop()
	if not _wet:
		return
	var sound := Level3DAudio.stream(RAIN_SOUND)
	if sound == null:
		return
	_rain_sound.stream = sound
	_rain_sound.bus = Level3DAudio.bus(RAIN_SOUND)
	_rain_sound.volume_db = Level3DAudio.SILENT_DB
	_rain_sound.play()
	if _rain_fade != null:
		_rain_fade.kill()
	_rain_fade = create_tween()
	_rain_fade.tween_property(_rain_sound, "volume_db", Level3DAudio.volume_db(RAIN_SOUND), RAIN_SOUND_IN)


# The rain heard away over `seconds`, as the screen takes its song away.
func fade_rain(seconds: float) -> void:
	if _rain_fade != null:
		_rain_fade.kill()
		_rain_fade = null
	if _rain_sound.playing:
		_rain_fade = create_tween()
		_rain_fade.tween_property(_rain_sound, "volume_db", Level3DAudio.SILENT_DB, seconds)


# The old print (the header): a rect over the frame, drawn after it and so
# after the oaks' ink, reading it back.
func _add_film() -> void:
	_film = ShaderMaterial.new()
	_film.shader = FILM_SHADER
	if not _wet_lens:
		_film.set_shader_parameter("drops", 0.0)
	var print_over := ColorRect.new()
	print_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	print_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print_over.material = _film
	add_child(print_over)


# The glb's trees an oak each, where they stood and as tall, give or take
# OAK_GROW; its bushes gone (the header).
func _plant_oaks(scene: Node) -> void:
	var oaks: Array[ArrayMesh] = []
	for path in OAK_PATHS:
		oaks.append(_oak_mesh(load(path) as PackedScene))
	var n := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var object_name := String(node.name)
		if object_name.contains("Bush"):
			node.get_parent().remove_child(node)
			node.free()
			continue
		if not object_name.contains("Tree"):
			continue
		var ours := node as MeshInstance3D
		var at := _transform_in(ours, scene)
		var height := ours.mesh.get_aabb().size.y * at.basis.get_scale().y
		ours.get_parent().remove_child(ours)
		ours.free()
		var mesh := oaks[n % oaks.size()]
		var oak := MeshInstance3D.new()
		oak.name = "Oak_%d" % n
		oak.mesh = mesh
		var scale_by := height / mesh.get_aabb().end.y * OAK_GROW
		oak.basis = Basis(Vector3.UP, n * OAK_TURN).scaled(Vector3.ONE * scale_by)
		oak.position = Vector3(at.origin.x, _foot_ground(at.origin, _trunk_reach(mesh) * scale_by) - OAK_SINK,
				at.origin.z)
		oak.extra_cull_margin = Level3DWind.CULL_MARGIN
		oak.layers = OAK_LAYER
		scene.add_child(oak)
		n += 1
	if n > 0:
		var ink := ShaderMaterial.new()
		ink.shader = OAK_INK_SHADER
		ink.set_shader_parameter("mask", _mask.get_texture())
		Level3DHull.track(ink)
		ink.set_shader_parameter("fog_colour", RAIN_FOG_COLOUR)
		material = ink


# An oak's glb as one mesh without the surfaces it does not draw here.
static func _oak_mesh(scene: PackedScene) -> ArrayMesh:
	var root := scene.instantiate()
	var source := (root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh as ArrayMesh
	var out := ArrayMesh.new()
	for surface in source.get_surface_count():
		var material := source.surface_get_material(surface)
		if material != null and material.resource_name in OAK_DROPPED:
			continue
		# The leaves' burn ramp in their custom channels: their format given
		# again, or the arrays are refused.
		out.add_surface_from_arrays(source.surface_get_primitive_type(surface), source.surface_get_arrays(surface),
				[], {}, source.surface_get_format(surface) & ~Mesh.ARRAY_FORMAT_VERTEX)
		out.surface_set_material(out.get_surface_count() - 1, material)
		out.surface_set_name(out.get_surface_count() - 1, source.surface_get_name(surface))
	root.free()
	return out


# How far the trunk's foot reaches from its middle, the model's metres: the
# bark's furthest vertex below OAK_FOOT, its root flare.
static func _trunk_reach(mesh: ArrayMesh) -> float:
	var reach := 0.2
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		if material == null or not material.resource_name.contains("Bark"):
			continue
		for v in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			if v.y < OAK_FOOT:
				reach = maxf(reach, Vector2(v.x, v.z).length())
	return reach


# The lowest ground under a foot at `at` reaching `reach` metres round:
# its middle and a ring of points.
func _foot_ground(at: Vector3, reach: float) -> float:
	var low := _ground_at(at.x, -at.z)
	for i in 12:
		var a := TAU * i / 12.0
		for r in [reach * 0.5, reach]:
			low = minf(low, _ground_at(at.x + cos(a) * r, -(at.z + sin(a) * r)))
	return low


# An oak's double in the outline's mask (the header, and
# level3d_oak_ink.gdshader): its mesh again on MASK_LAYER, flat in its own
# colour -- its number in blue -- its leaves cut out and swaying as the
# oak's are, casting nothing.
func _outline_oak(oak: MeshInstance3D) -> void:
	var number := int(String(oak.name).trim_prefix("Oak_"))
	var double := MeshInstance3D.new()
	double.name = "Mask"
	double.mesh = oak.mesh
	double.layers = MASK_LAYER
	double.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	double.extra_cull_margin = oak.extra_cull_margin
	var crown := Level3DWind._crown(oak.mesh as ArrayMesh)
	for surface in oak.mesh.get_surface_count():
		var source := oak.mesh.surface_get_material(surface) as BaseMaterial3D
		var material := _wind_material(OAK_MASK_SHADER)
		material.set_shader_parameter("mask_colour", Color(1.0, 0.0, (number % 16) / 16.0))
		material.set_shader_parameter("fog_density", _fog_density)
		if source != null and source.albedo_texture != null:
			material.set_shader_parameter("albedo_tex", source.albedo_texture)
			material.set_shader_parameter("scissor", source.alpha_scissor_threshold)
		else:
			material.set_shader_parameter("scissor", 0.0)
		material.set_shader_parameter("wind_crown", crown.at)
		material.set_shader_parameter("wind_radius", crown.reach)
		material.set_shader_parameter("wind_flap", 0.0)
		material.set_shader_parameter("wind_give", OAK_GIVE)
		double.set_surface_override_material(surface, material)
	oak.add_child(double)


# The oaks and the grass in the wind (the header).
func _add_wind(scene: Node) -> void:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		var object_name := String(instance.name)
		if object_name.begins_with("Oak_"):
			_sway(instance, OAK_GIVE)
			_outline_oak(instance)
		elif object_name.begins_with("GO_Grass"):
			_grass(instance, scene)


# A tree on level3d_wind.gdshaderinc: its crown the top of its trunk
# (Level3DWind's measure), or of its middle if it has none; no fronds to
# flap. An oak's leaves and its puffs' cores on level3d_leaf_wind.gdshader,
# the rest soft (level3d_wind_soft.gdshader); a contour, if it has one, goes
# with it (level3d_hull_wind.gdshader).
func _sway(instance: MeshInstance3D, give: float) -> void:
	var mesh := instance.mesh as ArrayMesh
	if mesh == null:
		return
	instance.extra_cull_margin = Level3DWind.CULL_MARGIN
	if not _wind_made.has(mesh):
		var crown := Level3DWind._crown(mesh)
		if crown.is_empty():
			var box := mesh.get_aabb()
			crown = {"at": Vector3(0.0, box.end.y, 0.0), "reach": maxf(box.size.x, box.size.z) * 0.5}
		var made := []
		for surface in mesh.get_surface_count():
			var source := mesh.surface_get_material(surface)
			var material: ShaderMaterial = null
			if Level3DHull.is_hull(source):
				material = _wind_material(Level3DWind.HULL_SHADER)
				Level3DHull.track(material)
			elif source is BaseMaterial3D and (source.resource_name.contains("Leaf")
					or source.resource_name.contains("Core")):
				var base := source as BaseMaterial3D
				material = _wind_material(LEAF_WIND_SHADER)
				material.set_shader_parameter("albedo", base.albedo_color)
				if base.albedo_texture != null:
					material.set_shader_parameter("albedo_tex", base.albedo_texture)
				material.set_shader_parameter("scissor", base.alpha_scissor_threshold)
				material.set_shader_parameter("tint", OAK_TINT)
			elif source is BaseMaterial3D and not source.resource_name.ends_with("Contour"):
				material = _wind_material(WIND_SOFT_SHADER)
				material.set_shader_parameter("albedo", (source as BaseMaterial3D).albedo_color)
			if material != null:
				material.resource_name = source.resource_name
				material.set_shader_parameter("wind_crown", crown.at)
				material.set_shader_parameter("wind_radius", crown.reach)
				material.set_shader_parameter("wind_flap", 0.0)
				material.set_shader_parameter("wind_give", give)
			made.append(material)
		_wind_made[mesh] = made
	var materials: Array = _wind_made[mesh]
	for surface in materials.size():
		if materials[surface] != null:
			instance.set_surface_override_material(surface, materials[surface])


# The grass: its mesh again with each vertex's height over the ground in
# UV2.x, and its surfaces on level3d_grass_wind.gdshader. With `dome` its
# normals are a dome's over each tuft rather than each blade's own, as the
# BlenderMCP board's cel tufts have (Grass3D, CelTufts): a blade lit by its
# own facing breaks the grass up into flecks, the dome gives a tuft a dark
# side and a light top. A tuft is what stands in a DOME_CELL square: the
# grass is one mesh and does not say which blade is whose.
static var dome := true
const DOME_CELL := 0.3
const DOME_BELOW := 0.25     # the dome's centre under the root, a share of the tuft's height

func _grass(instance: MeshInstance3D, scene: Node) -> void:
	var source := instance.mesh as ArrayMesh
	if source == null:
		return
	var to_scene := _transform_in(instance, scene)
	var surfaces := []
	# Each cell's feet (x, z summed, count) and tallest blade.
	var feet := {}
	var tall := {}
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var at := PackedVector3Array()
		at.resize(vertices.size())
		var heights := PackedVector2Array()
		heights.resize(vertices.size())
		for i in vertices.size():
			at[i] = to_scene * vertices[i]
			var h := at[i].y - _ground_at(at[i].x, -at[i].z)
			heights[i] = Vector2(h, 0.0)
			var cell := Vector2i(floori(at[i].x / DOME_CELL), floori(at[i].z / DOME_CELL))
			tall[cell] = maxf(tall.get(cell, 0.0), h)
			if h < 0.05:
				var sum: Vector3 = feet.get(cell, Vector3.ZERO)
				feet[cell] = sum + Vector3(at[i].x, at[i].z, 1.0)
		arrays[Mesh.ARRAY_TEX_UV2] = heights
		surfaces.append([arrays, at, heights])
	var to_mesh := to_scene.basis.inverse()
	var out := ArrayMesh.new()
	for surface in surfaces.size():
		var arrays: Array = surfaces[surface][0]
		if dome:
			var at: PackedVector3Array = surfaces[surface][1]
			var heights: PackedVector2Array = surfaces[surface][2]
			var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
			for i in at.size():
				var cell := Vector2i(floori(at[i].x / DOME_CELL), floori(at[i].z / DOME_CELL))
				var sum: Vector3 = feet.get(cell, Vector3(at[i].x, at[i].z, 1.0))
				var centre := Vector2(sum.x, sum.y) / sum.z
				var up: float = heights[i].x + DOME_BELOW * tall.get(cell, 0.3)
				normals[i] = (to_mesh * Vector3(at[i].x - centre.x, up, at[i].z - centre.y)).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		out.surface_set_name(surface, source.surface_get_name(surface))
		var base := source.surface_get_material(surface) as BaseMaterial3D
		var material := _wind_material(GRASS_WIND_SHADER)
		material.set_shader_parameter("keep_normal", dome)
		if base != null:
			material.resource_name = base.resource_name
			material.set_shader_parameter("albedo", base.albedo_color)
		out.surface_set_material(surface, material)
	instance.mesh = out
	instance.extra_cull_margin = 0.2
	for surface in out.get_surface_count():
		instance.set_surface_override_material(surface, null)


# The wind in the grass and the oaks `times` its strength; none under --no-wind.
func _set_wind_strength(times: float) -> void:
	if OS.get_cmdline_user_args().has("--no-wind"):
		return
	for material in _wind:
		material.set_shader_parameter("wind_strength", times)


func _wind_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("wind_fps", Level3DWind.STEPPED_FPS if Level3DWind.is_stepped() else 0.0)
	material.set_shader_parameter("wind_clock", _wind_clock)
	if OS.get_cmdline_user_args().has("--no-wind"):
		material.set_shader_parameter("wind_strength", 0.0)
	_wind.append(material)
	return material
