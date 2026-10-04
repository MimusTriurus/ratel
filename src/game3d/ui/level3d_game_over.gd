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
# graves, the crosses, the trees, the bushes and the rocks; not the ground or
# the grass.
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
	_world.add_child(scene)
	_camera = scene.find_child("GO_Camera*", true, false) as Camera3D
	if _camera != null:
		_camera.current = true
		_camera_rest = _camera.transform


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
	_time += delta
	for g in _guard:
		if not g.saluting and _time >= g.at:
			(g.player as AnimationPlayer).play(SALUTE, SALUTE_BLEND)
			g.saluting = true
