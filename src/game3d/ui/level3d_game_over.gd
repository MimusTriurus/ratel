# The 3D preview's game over: the prisoners the players rescued, their backs
# to the camera, saluting the players' graves -- a cross for the first, a
# headstone for the second, with two players only -- and up the slope behind
# them a cross for every prisoner the run did not rescue. Cannon Fodder's
# Boot Hill turned round: here the graves are the players', and those who
# stand at them are the ones they brought home.
#
# Built from jackal_game_over.glb, which the GameOver scene of
# resources/3d/jackal_boot_hill.blend exports (export_game_over() in its
# jackal_boot_hill.py): the ground, the trees, the bushes, the rocks, the
# grass and the camera as they stand, and under Props what this places, as
# many of each as the run wants -- the two graves, the mound under them, a
# prisoner's cross. The guard is the prisoners' own glb on Pow_Attention and
# Pow_Salute (jackal_trooper.py). Where it all stands is jackal_boot_hill.py's
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
class_name Level3DGameOver
extends TextureRect

const SCENE_PATH := "res://resources/3d/jackal_game_over.glb"
const POW_PATH := "res://resources/3d/jackal_trooper_pow.glb"
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
const POW_SCALE := 0.54      # the prisoner's 1.8 m to the level's metre, as there
const SEED := 7

const ATTENTION := "Pow_Attention"
const SALUTE := "Pow_Salute"
const LOOP_PAD := 1.0 / 24.0  # a loop is exported to the frame before it repeats
# The guard at attention for SALUTE_FROM seconds, then saluting from the aisle
# out, SALUTE_STEP apart a file and half that a rank.
const SALUTE_FROM := 1.2
const SALUTE_STEP := 0.08
const SALUTE_BLEND := 0.12
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

const vec3 HORIZON = vec3(1.0, 0.77, 0.57);
const vec3 ROSE = vec3(0.93, 0.70, 0.70);
const vec3 HIGH = vec3(0.51, 0.58, 0.81);

void sky() {
	float up = EYEDIR.y;
	vec3 c = mix(HORIZON, ROSE, smoothstep(0.0, 0.14, up));
	c = mix(c, HIGH, smoothstep(0.14, 0.36, up));
	COLOR = up < 0.0 ? HORIZON : c;
}
"""

var viewport: SubViewport
var shown := false

var _world: Node3D
var _camera: Camera3D
var _camera_rest := Transform3D.IDENTITY   # where the glb has it
var _templates := {}         # Prop_* name -> its node, out of the tree
var _pow_scene: PackedScene
var _ground_mesh: TriangleMesh
var _ground_xform := Transform3D.IDENTITY
var _soft := {}              # a glb's material -> its soft copy
var _placed: Array[Node3D] = []   # this run's graves, mounds, crosses and guard
var _guard: Array[Dictionary] = []  # {player: AnimationPlayer, at: seconds, saluting}
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
var _mask: SubViewport
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
	_pow_scene = load(POW_PATH)
	# The oaks' mask (_outline_oaks): the same world from the same camera,
	# without the smoothing, which would blend an oak's colour into its
	# neighbours'.
	_mask = SubViewport.new()
	_mask.world_3d = viewport.find_world_3d()
	_mask.msaa_3d = Viewport.MSAA_DISABLED
	_mask.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_mask.set_meta(SOFT_LIGHT, true)
	add_child(_mask)
	_mask_camera = Camera3D.new()
	_mask_camera.cull_mask = 0xFFFFF & ~OAK_LAYER
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
	environment.ambient_light_color = AMBIENT.linear_to_srgb()
	environment.ambient_light_energy = AMBIENT_ENERGY * gain
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.light_color = SUN_COLOUR.linear_to_srgb()
	sun.light_energy = SUN_ENERGY * gain
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	sun.basis = Basis.looking_at(SUN_TRAVEL, Vector3.UP)
	_world.add_child(sun)

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
	_ground_mesh = hill.mesh.generate_triangle_mesh()
	_ground_xform = _transform_in(hill, scene)
	_soften(scene)
	_plant_oaks(scene)
	_add_wind(scene)
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
# stepped on the glb's own (the prisoners' are the stage's too), and no
# specular, as the scene was drawn in Blender. The ground takes its colours
# from its vertices. The contour's material is left as it is.
func _soften(root: Node) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var instance := node as MeshInstance3D
		Level3DHull.apply(instance)
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
# crosses. The guard comes to attention and salutes (_process).
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
			var guard := _pow_scene.instantiate() as Node3D
			_soften(guard)
			guard.scale = Vector3.ONE * POW_SCALE
			_put(guard, x, GUARD_Y - rank * RANK_GAP, PI + deg_to_rad(rng.randf_range(-3.0, 3.0)))
			guard.scale = Vector3.ONE * POW_SCALE
			_stand(guard, rng, SALUTE_FROM + (file + rank * 0.5) * SALUTE_STEP)
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
	_guard.append({"player": player, "at": at, "saluting": false})


func clear() -> void:
	for node in _placed:
		node.queue_free()
	_placed.clear()
	_guard.clear()
	shown = false
	visible = false


func _process(delta: float) -> void:
	if not shown:
		return
	# The render the size of the frame it fills.
	var want := Vector2i(size)
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
	for material in _wind:
		material.set_shader_parameter("wind_clock", _wind_clock)
	for g in _guard:
		if not g.saluting and _time >= g.at:
			(g.player as AnimationPlayer).play(SALUTE, SALUTE_BLEND)
			g.saluting = true


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
		ink.set_shader_parameter("pixels", Level3DHull.PIXELS)
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
				material.set_shader_parameter("pixels", Level3DHull.PIXELS)
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


func _wind_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("wind_fps", Level3DWind.STEPPED_FPS if Level3DWind.is_stepped() else 0.0)
	material.set_shader_parameter("wind_clock", _wind_clock)
	if OS.get_cmdline_user_args().has("--no-wind"):
		material.set_shader_parameter("wind_strength", 0.0)
	_wind.append(material)
	return material
